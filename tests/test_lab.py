"""Offline contract tests; synthetic fixtures are not AWS execution evidence."""
import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('lab', ROOT / 'scripts/lab.py')
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)


def response(text='', code=0, error=''):
    return {'Status': 'Success' if code == 0 else 'Failed', 'ResponseCode': code,
            'StandardOutputContent': text, 'StandardErrorContent': error}


class SafetyContracts(unittest.TestCase):
    def setUp(self):
        self.c = dict(expected_account_id='123456789012', region='us-east-1',
                      lab_id='aws-netlab', scenario='baseline')
        self.inv = {'instances': {'server': {'ip': '10.20.10.10'}}}
        self.results = {
            'http_ip': response('AWS network lab: HTTP healthy'),
            'http_dns': response('AWS network lab: HTTP healthy'),
            'local_http': response('AWS network lab: HTTP healthy'),
            'dns': response('status: NOERROR\n10.20.10.10'),
            's3': response('AWS network lab: S3 healthy'),
            'server_s3': response('AWS network lab: S3 healthy'),
            'blocked_ssh': response(code=28),
            'reverse_http': response(code=28),
        }

    def test_settings_reject_shell_injection(self):
        for key in ('region', 'lab_id', 'expected_account_id'):
            c = dict(self.c, **{key: 'x; touch /tmp/unsafe'})
            with self.assertRaises(lab.LabError):
                lab.validate_settings(c)

    def test_account_guard(self):
        with patch.object(lab, 'aws_json', return_value={'Account': '999999999999'}):
            with self.assertRaises(lab.LabError):
                lab.identity(self.c)

    def test_requires_explicit_mutation_flag(self):
        with self.assertRaises(lab.LabError):
            lab.require_approval(type('Args', (), {'approve': False})())

    def test_plan_rejects_unrelated_drift(self):
        plan = {'resource_changes': [{'mode': 'managed', 'address': 'aws_instance.foreign',
                                     'change': {'actions': ['delete']}}]}
        with self.assertRaises(lab.LabError):
            lab.guard_plan(plan, allowed=set(lab.FAULT_ADDRESSES.values()))
        with self.assertRaises(lab.LabError):
            lab.guard_plan(plan, deployment=True)

    def test_plan_accepts_only_selected_fault(self):
        for fault, addr in lab.FAULT_ADDRESSES.items():
            plan = {'resource_changes': [{'mode': 'managed', 'address': addr,
                                         'change': {'actions': ['update']}}]}
            lab.guard_plan(plan, allowed={addr})
            other = next(a for f, a in lab.FAULT_ADDRESSES.items() if f != fault)
            with self.assertRaises(lab.LabError):
                lab.guard_plan(plan, allowed={other})

    def test_replacement_is_not_a_fault(self):
        addr = lab.FAULT_ADDRESSES['s3-policy']
        plan = {'resource_changes': [{'mode': 'managed', 'address': addr,
                                     'change': {'actions': ['delete', 'create']}}]}
        with self.assertRaises(lab.LabError):
            lab.guard_plan(plan, allowed={addr})

    def test_healthy_content_required(self):
        lab.check_results('baseline', self.results, self.inv)
        self.results['s3'] = response('a different object')
        with self.assertRaises(lab.LabError):
            lab.check_results('baseline', self.results, self.inv)

    def test_network_fault_requires_timeout(self):
        for fault in ('routing', 'security-group', 'nacl'):
            r = copy.deepcopy(self.results)
            r['http_ip'] = r['http_dns'] = response(code=28)
            lab.check_results(fault, r, self.inv)
            r['http_ip'] = response(code=7)
            with self.assertRaises(lab.LabError):
                lab.check_results(fault, r, self.inv)

    def test_dns_fault_checks_nxdomain_not_dig_exit_code(self):
        r = copy.deepcopy(self.results)
        r['http_dns'] = response(code=6)
        r['dns'] = response('status: NXDOMAIN')
        lab.check_results('dns', r, self.inv)
        r['dns'] = response('status: SERVFAIL')
        with self.assertRaises(lab.LabError):
            lab.check_results('dns', r, self.inv)

    def test_s3_fault_rejects_transport_failure(self):
        r = copy.deepcopy(self.results)
        r['s3'] = response(code=254, error='An error occurred (AccessDenied)')
        lab.check_results('s3-policy', r, self.inv)
        r['s3'] = response(code=255, error='Connect timeout')
        with self.assertRaises(lab.LabError):
            lab.check_results('s3-policy', r, self.inv)

    def test_unaffected_server_s3_is_required(self):
        r = copy.deepcopy(self.results)
        r['s3'] = response(code=254, error='AccessDenied')
        r['server_s3'] = response(code=254, error='AccessDenied')
        with self.assertRaises(lab.LabError):
            lab.check_results('s3-policy', r, self.inv)

    def test_aws_denied_is_not_deletion(self):
        result = subprocess.CompletedProcess([], 255, '', 'An error occurred (AccessDenied)')
        with patch.object(lab, 'aws', return_value=result):
            with self.assertRaises(lab.LabError):
                lab.absent(self.c, ('s3api', 'head-bucket'), error_codes=('404',))

    def test_recognized_notfound_is_deletion(self):
        result = subprocess.CompletedProcess([], 255, '', 'An error occurred (404)')
        with patch.object(lab, 'aws', return_value=result):
            self.assertTrue(lab.absent(self.c, ('s3api', 'head-bucket'), error_codes=('404',)))

    def test_running_instance_is_not_deleted(self):
        body = {'Reservations': [{'Instances': [{'State': {'Name': 'running'}}]}]}
        result = subprocess.CompletedProcess([], 0, json.dumps(body), '')
        with patch.object(lab, 'aws', return_value=result):
            self.assertFalse(lab.absent(self.c, (), 'Reservations'))

    def test_peering_requires_deleted_status(self):
        for status, expected in [('active', False), ('deleted', True)]:
            body = {'VpcPeeringConnections': [{'Status': {'Code': status}}]}
            result = subprocess.CompletedProcess([], 0, json.dumps(body), '')
            with patch.object(lab, 'aws', return_value=result):
                self.assertEqual(lab.absent(self.c, (), 'VpcPeeringConnections'), expected)

    def test_bootstrap_template_shell_syntax(self):
        template = (ROOT / 'terraform/modules/compute/user-data.sh.tftpl').read_text()
        for server in (True, False):
            start, conditional = template.split('%{ if is_server ~}')
            body, end = conditional.split('%{ endif ~}')
            rendered = start + (body if server else '') + end
            result = subprocess.run(['bash', '-n'], input=rendered, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
