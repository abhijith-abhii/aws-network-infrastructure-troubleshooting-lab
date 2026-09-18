# Setup, authentication, and permissions

## Local prerequisites

Use Linux, macOS, or WSL with Python 3.9+, Terraform 1.10–1.x (CI pins 1.14.7), AWS CLI v2, Git, and Bash. Install the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), [Terraform](https://developer.hashicorp.com/terraform/install), and [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) from official distributions. The plugin is required for `session`; Run Command tests use the CLI directly. Development dependencies in `requirements-dev.txt` use Python 3.12 in CI.

Your workstation needs internet access to the Terraform registry/releases and AWS control-plane APIs. This does not give the instances internet access. Do not run the deployment controller on a lab EC2 instance: its IAM and networking intentionally cannot provision infrastructure.

## AWS account and identity

Use a dedicated sandbox account with no production workloads. Use IAM Identity Center/SSO or a short-lived assumed role, not root or hard-coded access keys:

```bash
aws configure sso --profile netlab
aws sso login --profile netlab
export AWS_PROFILE=netlab
aws sts get-caller-identity
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit the copy, including the expected sandbox account ID.
python3 scripts/lab.py prereq --account YOUR_12_DIGIT_ACCOUNT_ID --region us-east-1 --lab-id aws-netlab
```

The command checks identity and advertised `ssm`, `ssmmessages`, and `s3` endpoint services and saves `.lab/config.tfvars.json`. The provider also uses `allowed_account_ids`. Profiles and SSO caches stay outside Git. A unique lab ID is required for each concurrent copy; IAM names are account-global, so choose different IDs even across Regions. Service quotas must permit two VPCs, two EC2 instances, four interface endpoints and a private hosted zone.

## Deployment permissions

There is no universally least-privilege deployer policy independent of an account's SCPs, permissions boundaries, session policies, resource IDs, and regional controls. Have your sandbox administrator grant a scoped provisioning role. Review a Terraform plan against these concrete operations; this table is a permission specification, not a promise that an organization will allow deployment.

| Service | Needed by the deployment controller |
|---|---|
| STS | `GetCallerIdentity` |
| EC2 | Describe VPCs/subnets/AZs/images/instances/status/routes/SGs/ACLs/endpoints/prefix lists/peering/Flow Logs/volumes; create/delete VPCs, subnets, IGWs, route tables/associations/routes, SGs/rules, ACLs/entries/associations, endpoints, peering and Flow Logs; accept peering; run/terminate instances; associate instance profiles; modify relevant VPC/instance attributes; create/delete tags |
| IAM | Create/Get/Delete lab roles and instance profiles; Add/RemoveRoleFromInstanceProfile; Attach/DetachRolePolicy for `AmazonSSMManagedInstanceCore`; Put/Get/DeleteRolePolicy; List role/profile policies; tag/untag lab IAM resources; `PassRole` only for the three lab roles |
| S3 | Create/Delete dedicated bucket; bucket policy, encryption, public access block, ownership controls and tag read/write; GetBucketLocation/ListBucket; Put/Get/DeleteObject only under that lab bucket |
| Route 53 | Create/Get/Delete private hosted zone, list/change records, get change status, associate/disassociate both lab VPCs, tag/list tags |
| CloudWatch Logs | Create/Delete/Describe lab log group, set/delete retention, tag/list tags; FilterLogEvents and optionally StartQuery/GetQueryResults for analysis |
| SSM | Read public AL2023 image parameter; SendCommand using `AWS-RunShellScript` only to lab instances; GetCommandInvocation; DescribeInstanceInformation; Start/Resume/TerminateSession on lab instances/your sessions |

Scope resource-specific permissions to this lab's ARNs and constrain supported create actions with `aws:RequestTag/LabId` and `aws:TagKeys`. For IAM PassRole, restrict role ARNs and `iam:PassedToService` to `ec2.amazonaws.com` and `vpc-flow-logs.amazonaws.com` as appropriate. Some Describe/List APIs and service-delivery operations need `Resource: "*"`; do not apply a tag condition to an action that does not support it. The AWS-managed SSM document ARN is `arn:aws:ssm:REGION::document/AWS-RunShellScript`; instance and document authorization are separate. A permissions boundary on created roles may require adapting the modules.

Admin access in a disposable sandbox can bootstrap learning but is broader than these requirements; never grant this on a production account. The instance roles in the code are separate: they get the managed SSM core policy and narrowly scoped `s3:GetObject`, with no infrastructure mutation rights.

## Why private bootstrap works

The standard AL2023 x86_64 AMI includes SSM Agent. The chosen design requires Agent **3.3.40.0 or later**, which can use `ssmmessages` for modern messaging. Each VPC has `ssm` and `ssmmessages` interface endpoints with private DNS, TCP/443 SG access, and enabled VPC DNS. `ec2messages` is not provisioned for this modern-agent design, including in us-east-1. Bootstrap verifies the agent version and refuses to mark an old image ready. [AWS endpoint/agent reference](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-setting-up-messageAPIs.html).

On first scripted deployment the public SSM parameter is resolved by the **workstation**, and the AMI is pinned in the local configuration so future fault plans cannot silently refresh it. An explicit `prereq --ami-id` can pin an approved AL2023 standard image initially. Re-running prereq preserves an existing pin. Do not substitute Ubuntu, an AL2023 minimal AMI, a third-party image, or an old agent without revisiting bootstrap and endpoints.

AL2023's regional package repository is S3-hosted. The gateway endpoint permits `GetObject` on `al2023-repos-REGION-*/*`; other repos are disabled during DNF installation. The instance installs `curl-minimal`, `bind-utils` (`dig`), `iproute` (`ip`, `ss`), Python 3 and `awscli-2`. IPv4 is forced for this IPv4-only lab. No temporary NAT or prepared custom image is required. Third-party package repositories and pip are not reachable. AWS documents the [AL2023 gateway endpoint method](https://repost.aws/knowledge-center/ec2-al1-al2-update-yum-without-internet).

The server runs Python's small HTTP server under systemd as `nobody` with only bind-to-low-port capability. Its one harmless static page is supplied in user data. This server is for demonstration, not production traffic. The package/version resolution is tied to the selected AL2023 image repository release; it is not a claim of bit-for-bit reproducibility forever.

## Startup failures

`deploy` has a 20-minute SSM/bootstrap deadline. DNF has five bounded attempts, each limited to 180 seconds. If the deadline expires, resources may still be billing. Use `session client`/`session server` if the agent is online, then inspect:

```bash
sudo tail -100 /var/log/lab-bootstrap.log
sudo tail -100 /var/log/cloud-init-output.log
sudo systemctl status amazon-ssm-agent --no-pager
sudo tail -100 /var/log/amazon/ssm/amazon-ssm-agent.log
sudo cloud-init status --long
```

Check endpoint status/private DNS, VPC DNS attributes, endpoint SG source, private S3 route, package endpoint policy, and the instance profile. If SSM is offline, EC2 console system log/GetConsoleOutput and AWS resource configuration are available from the control plane. A very old agent may require changing the pinned image and intentionally replacing EC2; deploy's deletion guard will stop an unreviewed replacement. Do not add public SSH to repair the lab. You can always run Terraform restoration/teardown from the workstation. See [operations](operations.md).
