#!/usr/bin/env python3
"""Explicit, scoped lab operations. Uses local Terraform state and AWS CLI v2.

No AWS calls on import. Mutations require --approve. No shell=True or tag-wide deletes.
"""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
TF = ROOT / 'terraform'
LOCAL = ROOT / '.lab'
CONFIG = LOCAL / 'config.tfvars.json'
INVENTORY = LOCAL / 'inventory.json'
SCENARIOS = ('routing', 'security-group', 'nacl', 'dns', 's3-policy')
FAULT_ADDRESSES = {
    'routing': 'module.peering.aws_route.client_to_server[0]',
    'security-group': 'module.compute["server"].aws_vpc_security_group_ingress_rule.http[0]',
    'nacl': 'module.network["server"].aws_network_acl_rule.fault_return[0]',
    'dns': 'aws_route53_record.app[0]',
    's3-policy': 'module.endpoints["client"].aws_vpc_endpoint.s3',
}
ENV = dict(os.environ, AWS_PAGER='', AWS_CLI_AUTO_PROMPT='off', AWS_MAX_ATTEMPTS='3')


class LabError(RuntimeError):
    pass


def run(args, *, timeout=120, check=True, stream=False):
    result = subprocess.run([str(a) for a in args], text=True, env=ENV,
                            capture_output=not stream, timeout=timeout, cwd=ROOT)
    if check and result.returncode:
        raise LabError(f'Command failed ({result.returncode}): {shlex.join(map(str, args))}\n'
                       f'{result.stderr or "See command output above."}')
    return result


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(json.dumps(data, indent=2) + '\n')
    temp.chmod(0o600)
    temp.replace(path)


def settings():
    if not CONFIG.exists():
        raise LabError('Run prereq --account YOUR_ACCOUNT first; see README.')
    c = json.loads(CONFIG.read_text())
    validate_settings(c)
    return c


def validate_settings(c):
    if not re.fullmatch(r'[0-9]{12}', c.get('expected_account_id', '')):
        raise LabError('Expected account must contain 12 digits.')
    if not re.fullmatch(r'[a-z][a-z0-9-]{2,19}', c.get('lab_id', '')):
        raise LabError('Lab ID must be 3-20 lowercase letters, digits or hyphens.')
    if not re.fullmatch(r'[a-z]{2}-[a-z]+-[1-9]', c.get('region', '')):
        raise LabError('Invalid Region.')
    if c.get('scenario') not in ('baseline', *SCENARIOS):
        raise LabError('Invalid scenario.')
    if c.get('ami_id') and not re.fullmatch(r'ami-[0-9a-f]{17}', c['ami_id']):
        raise LabError('Invalid pinned AMI ID.')


def aws(c, *args, check=True):
    return run(['aws', *args, '--region', c['region'], '--output', 'json',
                '--cli-connect-timeout', '10', '--cli-read-timeout', '30'], check=check)


def aws_json(c, *args):
    return json.loads(aws(c, *args).stdout)


def identity(c):
    ident = aws_json(c, 'sts', 'get-caller-identity')
    if ident['Account'] != c['expected_account_id']:
        raise LabError('AWS identity does not match configured sandbox account. No mutation attempted.')
    return ident


def terraform(*args, **kwargs):
    return run(['terraform', f'-chdir={TF}', *args], **kwargs)


def inventory():
    data = json.loads(terraform('output', '-json', 'lab').stdout)
    c = settings()
    if (data['account_id'], data['region'], data['lab_id']) != (
            c['expected_account_id'], c['region'], c['lab_id']):
        raise LabError('State inventory does not match configured lab.')
    return data


def ownership(c, inv):
    """Check exact EC2 and VPC IDs before sending commands or applying scenarios."""
    identity(c)
    ids = [x['id'] for x in inv['instances'].values()]
    resp = aws_json(c, 'ec2', 'describe-instances', '--instance-ids', *ids)
    found = [i for r in resp['Reservations'] for i in r['Instances']]
    if {i['InstanceId'] for i in found} != set(ids):
        raise LabError('Expected lab instances missing.')
    for i in found:
        tags = {t['Key']: t['Value'] for t in i.get('Tags', [])}
        if tags.get('LabId') != c['lab_id'] or tags.get('ManagedBy') != 'Terraform':
            raise LabError('Instance ownership tags mismatch.')
    vpcs = aws_json(c, 'ec2', 'describe-vpcs', '--vpc-ids',
                    *[x['vpc_id'] for x in inv['networks'].values()])['Vpcs']
    for vpc in vpcs:
        if {t['Key']: t['Value'] for t in vpc.get('Tags', [])}.get('LabId') != c['lab_id']:
            raise LabError('VPC ownership tag mismatch.')


def require_approval(args):
    if not args.approve:
        raise LabError('This changes this lab in AWS. Re-run with --approve after reviewing the cost and scope.')


def prereq(args):
    for tool in ('terraform', 'aws'):
        if not shutil.which(tool):
            raise LabError(f'Missing {tool}; see docs/setup.md.')
    c = dict(expected_account_id=args.account, region=args.region,
             lab_id=args.lab_id, scenario='baseline')
    if args.ami_id:
        c['ami_id'] = args.ami_id
    validate_settings(c)
    if CONFIG.exists():
        old = settings()
        for key in ('expected_account_id', 'region', 'lab_id'):
            if old[key] != c[key]:
                raise LabError('Use a separate repository copy for a different lab/account/Region.')
        c = old  # Never reset an injected fault or pinned AMI on a prerequisite recheck.
    version = json.loads(terraform('version', '-json').stdout)['terraform_version']
    if tuple(map(int, version.split('.')[:2])) < (1, 10):
        raise LabError('Terraform >= 1.10 required.')
    cli = run(['aws', '--version']).stdout
    if not cli.startswith('aws-cli/2.'):
        raise LabError('AWS CLI v2 required.')
    print(json.dumps(identity(c), indent=2))
    names = [f'com.amazonaws.{c["region"]}.{s}' for s in ('ssm', 'ssmmessages', 's3')]
    aws_json(c, 'ec2', 'describe-vpc-endpoint-services', '--service-names', *names)
    save(CONFIG, c)
    print(f'Prerequisites OK: Terraform {version}; {cli.strip()}')
    print('Session Manager plugin: ' + ('found' if shutil.which('session-manager-plugin') else
                                        'not found (needed only for interactive sessions)'))
    print('Saved scoped configuration. No infrastructure created.')


def guard_plan(plan, allowed=None, deployment=False):
    changes = [r for r in plan.get('resource_changes', [])
               if r.get('mode') == 'managed' and r['change']['actions'] != ['no-op']]
    if allowed is not None:
        unexpected = [r['address'] for r in changes if r['address'] not in allowed]
        if unexpected:
            raise LabError('Unrelated drift/replacement in scenario plan; inspect before proceeding: ' + ', '.join(unexpected))
        if any('create' in r['change']['actions'] and 'delete' in r['change']['actions'] for r in changes):
            raise LabError('Scenario would replace a resource. Stopped.')
    if deployment and any('delete' in r['change']['actions'] for r in changes):
        raise LabError('Deploy refuses destructive changes; inspect Terraform plan and state manually.')
    return changes


def apply(c, *, allowed=None, deployment=False, destroy=False):
    save(CONFIG, c)  # Preserve intended fault even if apply is interrupted; restore can repair it.
    terraform('init', '-input=false', '-lockfile=readonly', timeout=300, stream=True)
    plan_path = LOCAL / 'lab.tfplan'
    flags = ['-destroy'] if destroy else []
    terraform('plan', '-input=false', '-lock-timeout=60s', f'-var-file={CONFIG}',
              f'-out={plan_path}', *flags, timeout=600, stream=True)
    plan = json.loads(terraform('show', '-json', str(plan_path)).stdout)
    guard_plan(plan, allowed=allowed, deployment=deployment)
    terraform('apply', '-input=false', '-lock-timeout=60s', str(plan_path), timeout=1800, stream=True)
    plan_path.unlink(missing_ok=True)
    if not destroy:
        save(INVENTORY, inventory())


def remote(c, inv, node, script, execution_timeout=120):
    if node not in ('client', 'server'):
        raise LabError('Unknown node.')
    iid = inv['instances'][node]['id']
    # SSM executes as root; strict scripts and exact IDs only, never tag-wide targeting.
    params = json.dumps({'commands': ['#!/bin/bash\nset -Eeuo pipefail\n' + script],
                         'executionTimeout': [str(execution_timeout)]})
    cmd = aws_json(c, 'ssm', 'send-command', '--instance-ids', iid,
                   '--document-name', 'AWS-RunShellScript', '--timeout-seconds', '60',
                   '--parameters', params, '--comment', f'{c["lab_id"]} diagnostics')['Command']['CommandId']
    deadline = time.monotonic() + execution_timeout + 120
    while time.monotonic() < deadline:
        result = aws(c, 'ssm', 'get-command-invocation', '--command-id', cmd,
                     '--instance-id', iid, check=False)
        if result.returncode:
            if 'InvocationDoesNotExist' in result.stderr:
                time.sleep(3)
                continue
            raise LabError(result.stderr)
        payload = json.loads(result.stdout)
        if payload['Status'] in ('Success', 'Failed', 'TimedOut', 'Cancelled', 'Cancelling'):
            return payload
        time.sleep(3)
    raise LabError(f'SSM command {cmd} exceeded bounded wait. Inspect its status in the SSM console.')


def successful(payload, label):
    if payload.get('Status') != 'Success' or payload.get('ResponseCode') != 0:
        raise LabError(f'{label}: {payload.get("Status")}\n{payload.get("StandardOutputContent", "")}\n'
                       f'{payload.get("StandardErrorContent", "")}')
    return payload.get('StandardOutputContent', '')


def ready(c, inv):
    deadline = time.monotonic() + 1200
    remaining = set(inv['instances'])
    while time.monotonic() < deadline and remaining:
        response = aws_json(c, 'ssm', 'describe-instance-information', '--filters',
                            json.dumps([{'Key': 'InstanceIds', 'Values': [v['id'] for v in inv['instances'].values()]}]))
        online = {i['InstanceId'] for i in response['InstanceInformationList'] if i['PingStatus'] == 'Online'}
        for node in tuple(remaining):
            if inv['instances'][node]['id'] in online:
                p = remote(c, inv, node, 'test -f /var/lib/lab-ready', execution_timeout=30)
                if p['Status'] == 'Success' and p['ResponseCode'] == 0:
                    remaining.remove(node)
        if remaining:
            print('Waiting for SSM/bootstrap: ' + ', '.join(sorted(remaining)), flush=True)
            time.sleep(15)
    if remaining:
        raise LabError('Startup timeout. See /var/log/lab-bootstrap.log, cloud-init-output.log and docs/setup.md.')


def probes(inv):
    server = inv['instances']['server']['ip']
    name = inv['hostname']
    bucket, key = shlex.quote(inv['bucket']), shlex.quote(inv['object_key'])
    region = shlex.quote(inv['region'])
    qname = shlex.quote(name)
    # Fixed fresh source port guarantees NACL return exercise and avoids old SG connection tracking.
    curl = "curl --noproxy '*' -fsS --connect-timeout 4 --max-time 8 --local-port 40000-40100"
    return {
        'http_ip': f'{curl} http://{server}/',
        'http_dns': f'{curl} http://{name}/',
        'dns': f'dig +time=2 +tries=1 {qname} A',
        's3': f'aws s3api get-object --region {region} --bucket {bucket} --key {key} /tmp/netlab-object.txt --cli-connect-timeout 4 --cli-read-timeout 10 >/dev/null && cat /tmp/netlab-object.txt',
        'blocked_ssh': f"curl --noproxy '*' -sS --connect-timeout 3 --max-time 4 http://{server}:22/",
        'reverse_http': f"curl --noproxy '*' -fsS --connect-timeout 3 --max-time 4 http://{inv['instances']['client']['ip']}/",
        'local_http': 'curl --noproxy "*" -fsS --connect-timeout 2 --max-time 4 http://127.0.0.1/',
    }


def check_results(scenario, results, inv):
    """Reject wrong failure modes: HTTP timeout, NXDOMAIN, or explicit AccessDenied."""
    def ok(key, text=None):
        out = successful(results[key], key)
        if text and text not in out:
            raise LabError(f'{key}: expected content missing: {text}')
        return out
    ok('local_http', 'AWS network lab: HTTP healthy')
    ok('server_s3', 'AWS network lab: S3 healthy')
    for key in ('blocked_ssh', 'reverse_http'):
        p = results[key]
        if p.get('Status') != 'Failed' or p.get('ResponseCode') != 28:
            raise LabError(f'{key}: denied-path control must time out (curl 28).')
    for key in ('http_ip', 'http_dns'):
        p = results[key]
        code = p.get('ResponseCode')
        if scenario in ('routing', 'security-group', 'nacl'):
            if p.get('Status') != 'Failed' or code != 28:
                raise LabError(f'{key}: expected curl timeout (28), got {code}/{p.get("Status")}')
        elif scenario == 'dns' and key == 'http_dns':
            if p.get('Status') != 'Failed' or code != 6:
                raise LabError('Expected curl name resolution failure (6).')
        else:
            ok(key, 'AWS network lab: HTTP healthy')
    dns = ok('dns')  # dig exits zero even for NXDOMAIN: inspect the DNS status explicitly.
    if scenario == 'dns':
        if 'status: NXDOMAIN' not in dns:
            raise LabError('Expected NXDOMAIN for the lab hostname.')
    elif 'status: NOERROR' not in dns or inv['instances']['server']['ip'] not in dns:
        raise LabError('Expected NOERROR and server address in DNS answer.')
    if scenario == 's3-policy':
        p = results['s3']
        if p.get('Status') != 'Failed' or 'AccessDenied' not in p.get('StandardErrorContent', ''):
            raise LabError('Expected S3 AccessDenied, not a network timeout or another error.')
    else:
        ok('s3', 'AWS network lab: S3 healthy')


def connectivity(c, inv, expected, *, wait_seconds=0):
    if inv['scenario'] != expected:
        raise LabError(f'State scenario is {inv["scenario"]}; requested test is {expected}.')
    ownership(c, inv)
    p = probes(inv)
    # Fresh probes on every attempt. DNS negative caches may persist ~900 seconds.
    deadline = time.monotonic() + wait_seconds
    while True:
        results = {key: remote(c, inv, 'client', p[key]) for key in ('http_ip', 'http_dns', 'dns', 's3', 'blocked_ssh')}
        results['reverse_http'] = remote(c, inv, 'server', p['reverse_http'])
        results['local_http'] = remote(c, inv, 'server', p['local_http'])
        results['server_s3'] = remote(c, inv, 'server', p['s3'])
        path = ROOT / 'evidence' / f'{stamp()}-{expected}-tests.json'
        save(path, {'captured_at': dt.datetime.now(dt.timezone.utc).isoformat(),
                    'scenario': expected, 'results': results})
        try:
            check_results(expected, results, inv)
            print(f'PASS: {expected} connectivity and unaffected control tests; evidence: {path.relative_to(ROOT)}')
            return
        except LabError:
            if time.monotonic() >= deadline:
                raise
            print('Waiting for network/policy/DNS propagation; retrying bounded tests.', flush=True)
            time.sleep(15)


def stamp():
    return dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')


def flow_logs(c, inv):
    ownership(c, inv)
    start = int(time.time() * 1000)
    p = probes(inv)
    remote(c, inv, 'client', p['http_ip'])  # Generates the scenario's traffic, even on expected failure.
    remote(c, inv, 'server', p['s3'])
    deadline = time.monotonic() + 900
    enis = {i['eni'] for i in inv['instances'].values()}
    while time.monotonic() < deadline:
        logs = aws_json(c, 'logs', 'filter-log-events', '--log-group-name', inv['log_group'],
                        '--start-time', str(start - 120000))
        seen = {e['message'].split()[2] for e in logs.get('events', [])
                if len(e['message'].split()) == 14 and e['message'].split()[-1] == 'OK'}
        if enis <= seen:
            path = ROOT / 'evidence' / f'{stamp()}-flow-logs.json'
            save(path, logs)
            print(f'PASS: recent OK Flow Log records from both workload ENIs; {path.relative_to(ROOT)}')
            return
        time.sleep(20)
    raise LabError('No recent OK Flow Log records for both ENIs within 15 minutes. Check delivery status/IAM; do not assume no traffic.')


def capture(c, inv):
    ownership(c, inv)
    folder = ROOT / 'evidence' / stamp()
    save(folder / 'inventory.json', inv)
    calls = {
        'routes': ('ec2', 'describe-route-tables', '--route-table-ids', *[n['private_route_table_id'] for n in inv['networks'].values()]),
        'security-groups': ('ec2', 'describe-security-groups', '--group-ids', *[n['sg'] for n in inv['instances'].values()]),
        'acls': ('ec2', 'describe-network-acls', '--network-acl-ids', *[n['private_acl_id'] for n in inv['networks'].values()]),
        'endpoints': ('ec2', 'describe-vpc-endpoints', '--vpc-endpoint-ids', *[n['s3_endpoint_id'] for n in inv['networks'].values()]),
        'dns': ('route53', 'list-resource-record-sets', '--hosted-zone-id', inv['zone_id']),
        'flow-status': ('ec2', 'describe-flow-logs', '--flow-log-ids', *inv['flow_log_ids']),
        'flows': ('logs', 'filter-log-events', '--log-group-name', inv['log_group'], '--start-time', str(int((time.time()-1800)*1000))),
        'bucket-policy': ('s3api', 'get-bucket-policy', '--bucket', inv['bucket']),
    }
    for name, command in calls.items():
        save(folder / f'{name}.json', aws_json(c, *command))
    for node, instance in inv['instances'].items():
        save(folder / f'{node}-object-iam.json', aws_json(c, 'iam', 'get-role-policy', '--role-name', instance['role'], '--policy-name', 'read-lab-and-regional-packages'))
        script = '\n'.join([
            'date -u; uname -r; cat /etc/os-release', 'ip -4 address; ip route; ss -tnap',
            f'dig +time=2 +tries=1 {shlex.quote(inv["hostname"])} A',
            f'dig +short ssm.{inv["region"]}.amazonaws.com',
            'amazon-ssm-agent -version; systemctl is-active amazon-ssm-agent',
            'tail -80 /var/log/lab-bootstrap.log',
            'systemctl status netlab-http --no-pager || true',
            'journalctl -u netlab-http -n 30 --no-pager || true',
        ])
        save(folder / f'{node}-diagnostics.json', remote(c, inv, node, script))
    print(f'Evidence saved: {folder.relative_to(ROOT)}. Review/redact before sharing.')


def absent(c, command, key=None, error_codes=()):
    result = aws(c, *command, check=False)
    if result.returncode:
        if any(f'({code})' in result.stderr for code in error_codes):
            return True
        raise LabError('Removal check failed (not evidence of deletion): ' + result.stderr)
    data = json.loads(result.stdout or '{}')
    if key == 'Reservations':
        return all(i['State']['Name'] == 'terminated' for r in data[key] for i in r['Instances'])
    if key == 'VpcPeeringConnections':
        return all(p['Status']['Code'] == 'deleted' for p in data[key])
    return not data.get(key, []) if key else False


def verify_destroy(c):
    identity(c)
    path = LOCAL / 'destroy-inventory.json'
    if not path.exists():
        raise LabError('Missing saved destruction inventory. Use destroy; inspect partial deployments manually.')
    inv = json.loads(path.read_text())
    if (inv['account_id'], inv['region'], inv['lab_id']) != (c['expected_account_id'], c['region'], c['lab_id']):
        raise LabError('Destruction inventory identity mismatch.')
    checks = [
        (('ec2', 'describe-volumes', '--filters', f'Name=tag:LabId,Values={c["lab_id"]}'), 'Volumes', ()),
        (('ec2', 'describe-vpc-peering-connections', '--vpc-peering-connection-ids', inv['peering_id']), 'VpcPeeringConnections', ('InvalidVpcPeeringConnectionID.NotFound',)),
        (('s3api', 'head-bucket', '--bucket', inv['bucket']), None, ('404', 'NoSuchBucket')),
        (('route53', 'get-hosted-zone', '--id', inv['zone_id']), None, ('NoSuchHostedZone',)),
        (('logs', 'describe-log-groups', '--log-group-name-prefix', inv['log_group']), 'logGroups', ()),
        (('iam', 'get-role', '--role-name', c['lab_id'] + '-flow-logs'), None, ('NoSuchEntity',)),
    ]
    for flow_id in inv['flow_log_ids']:
        checks.append((('ec2', 'describe-flow-logs', '--flow-log-ids', flow_id), 'FlowLogs', ('InvalidFlowLogId.NotFound',)))
    for node in inv['instances'].values():
        checks.extend([
            (('ec2', 'describe-instances', '--instance-ids', node['id']), 'Reservations', ('InvalidInstanceID.NotFound',)),
            (('iam', 'get-role', '--role-name', node['role']), None, ('NoSuchEntity',)),
            (('iam', 'get-instance-profile', '--instance-profile-name', node['profile']), None, ('NoSuchEntity',)),
        ])
    for net in inv['networks'].values():
        checks.append((('ec2', 'describe-vpcs', '--vpc-ids', net['vpc_id']), 'Vpcs', ('InvalidVpcID.NotFound',)))
        for eid in [net['s3_endpoint_id'], *net['interface_endpoint_ids']]:
            checks.append((('ec2', 'describe-vpc-endpoints', '--vpc-endpoint-ids', eid), 'VpcEndpoints', ('InvalidVpcEndpointId.NotFound',)))
    pending = checks
    deadline = time.monotonic() + 600
    while pending and time.monotonic() < deadline:
        pending = [item for item in pending if not absent(c, *item)]
        if pending:
            time.sleep(15)
    if pending:
        raise LabError('Some recorded resources are still visible; retry verify-destroy and inspect evidence.')
    resources = terraform('state', 'list').stdout.strip()
    if resources:
        raise LabError('Terraform state is not empty after destroy.')
    save(ROOT / 'evidence' / f'{stamp()}-destroy.json', {'status': 'PASS', 'checks': len(checks), 'inventory': inv})
    print('PASS: empty Terraform state and recorded resources removed. Check Billing later for delayed usage.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('prereq', help='Read-only AWS identity/service checks and local configuration')
    p.add_argument('--account', required=True)
    p.add_argument('--region', default='us-east-1')
    p.add_argument('--lab-id', default='aws-netlab')
    p.add_argument('--ami-id')
    for name in ('deploy', 'inject', 'restore', 'destroy', 'integration'):
        p = sub.add_parser(name)
        p.add_argument('--approve', action='store_true', help='Authorize this lab operation and its AWS costs')
        if name == 'inject':
            p.add_argument('scenario', choices=SCENARIOS)
    p = sub.add_parser('test')
    p.add_argument('--expect', default='baseline', choices=('baseline', *SCENARIOS))
    for name in ('evidence', 'flow-logs', 'inventory', 'verify-destroy'):
        sub.add_parser(name)
    p = sub.add_parser('session')
    p.add_argument('node', choices=('client', 'server'))
    args = parser.parse_args()
    if args.command == 'prereq':
        prereq(args)
        return
    c = settings()
    if args.command in ('deploy', 'inject', 'restore', 'destroy', 'integration'):
        require_approval(args)
        identity(c)
    if args.command == 'deploy':
        if c['scenario'] != 'baseline':
            raise LabError('Restore the pending/active fault first.')
        if not c.get('ami_id'):
            c['ami_id'] = aws_json(c, 'ssm', 'get-parameter', '--name',
                '/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64')['Parameter']['Value']
        apply(c, deployment=True)
        inv = inventory()
        ready(c, inv)
        connectivity(c, inv, 'baseline', wait_seconds=120)
    elif args.command == 'inject':
        inv = inventory()
        if c['scenario'] != 'baseline' or inv['scenario'] != 'baseline':
            raise LabError('Restore and verify baseline before injecting another fault.')
        connectivity(c, inv, 'baseline')
        c['scenario'] = args.scenario
        apply(c, allowed={FAULT_ADDRESSES[args.scenario]})
        connectivity(c, inventory(), args.scenario, wait_seconds=180)
    elif args.command == 'restore':
        # Also works without healthy SSM, using only the local AWS control plane.
        c['scenario'] = 'baseline'
        apply(c, allowed=set(FAULT_ADDRESSES.values()))
        inv = inventory()
        ready(c, inv)
        connectivity(c, inv, 'baseline', wait_seconds=1020)
    elif args.command == 'test':
        connectivity(c, inventory(), args.expect)
    elif args.command == 'evidence':
        capture(c, inventory())
    elif args.command == 'flow-logs':
        flow_logs(c, inventory())
    elif args.command == 'inventory':
        print(json.dumps(inventory(), indent=2))
    elif args.command == 'session':
        inv = inventory()
        ownership(c, inv)
        if not shutil.which('session-manager-plugin'):
            raise LabError('Install Session Manager plugin for interactive sessions.')
        run(['aws', 'ssm', 'start-session', '--region', c['region'], '--target',
             inv['instances'][args.node]['id']], stream=True, timeout=3600)
    elif args.command == 'destroy':
        # Preserve IDs before Terraform removes outputs; repeat after a partial destroy.
        try:
            inv = inventory()
            save(LOCAL / 'destroy-inventory.json', inv)
        except LabError:
            if not (LOCAL / 'destroy-inventory.json').exists():
                print('No complete outputs (possibly partial deployment). Terraform will destroy only its state; verify remaining resources manually.')
        apply(c, destroy=True)
        verify_destroy(c)
    elif args.command == 'verify-destroy':
        verify_destroy(c)
    elif args.command == 'integration':
        inv = inventory()
        if c['scenario'] != 'baseline':
            raise LabError('Restore baseline first.')
        connectivity(c, inv, 'baseline')
        for scenario in SCENARIOS:
            try:
                c['scenario'] = scenario
                apply(c, allowed={FAULT_ADDRESSES[scenario]})
                connectivity(c, inventory(), scenario, wait_seconds=180)
                capture(c, inventory())
            finally:
                c['scenario'] = 'baseline'
                apply(c, allowed=set(FAULT_ADDRESSES.values()))
                connectivity(c, inventory(), 'baseline', wait_seconds=1020)
        flow_logs(c, inventory())
        print('PASS: five faults and five restorations. Lab is still running; destroy separately.')


if __name__ == '__main__':
    try:
        main()
    except (LabError, subprocess.TimeoutExpired, OSError, ValueError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        print('A failed apply may leave resources running. Use restore or destroy; retain .lab and state.', file=sys.stderr)
        sys.exit(1)
