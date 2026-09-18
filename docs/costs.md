# Cost estimate — 2026-09-18

Planning estimate in USD for **us-east-1**, Linux On-Demand `t3.micro`, 730 hours/month, two 8-GiB gp3 volumes, one AZ per endpoint, four interface endpoints total. No credits, free tier, discounts, taxes or currency conversion are assumed. Prices are linked to official sources; verify Region and account pricing before deployment.

| Item | Assumption / unit price | Estimated month |
|---|---|---:|
| Two EC2 instances | `2 × 730 × $0.0104/hour` | $15.18 |
| Four SSM interface endpoints | `4 × 730 × $0.01/endpoint-AZ-hour` | $29.20 |
| gp3 root disks | `16 GiB × $0.08/GiB-month`, baseline IOPS/throughput | $1.28 |
| Private hosted zone | First 25 zones: $0.50/zone-month | $0.50 |
| Endpoint data processing | Assume 1 GB/month × $0.01/GB | $0.01 |
| Flow Logs ingestion | Assume 1 GB/month × $0.50/GB initial vended-log tier | $0.50 |
| Log storage / queries | Assume 0.1 GB average stored × $0.03, and 1 GB scanned × $0.005 | $0.008 |
| S3 object/storage/requests | Tiny object, ≤100 PUT and ≤1,000 GET; reserve | $0.01 |
| **Estimated total** | Rounded; usage assumptions are not measured | **$46.69 ≈ $47/month** |

Price references: [EC2 T3](https://aws.amazon.com/ec2/instance-types/t3/), [PrivateLink](https://aws.amazon.com/privatelink/pricing/), [EBS gp3](https://aws.amazon.com/ebs/volume-types/), [Route 53](https://aws.amazon.com/route53/pricing/), [CloudWatch](https://aws.amazon.com/cloudwatch/pricing/), [S3](https://aws.amazon.com/s3/pricing/). Logs Insights costs depend on bytes scanned, not just returned rows. Actual log traffic from SSM and package installation varies.

An **8-hour study session** has roughly $0.49 of EC2 + endpoint runtime, $0.014 of prorated EBS, plus logs, requests and the hosted-zone rule. Conservatively budget **about $1.10** assuming 0.1 GB endpoint processing and 0.1 GB log ingestion, small queries/requests, and a full $0.50 zone charge. Route 53 does not prorate the zone's monthly price; its documented within-12-hours deletion exception may avoid that charge, but this budget does not depend on it. Endpoint partial hours round upward. A session crossing billing boundaries or repeated creates can differ.

VPCs, subnets, route tables, SGs, ACLs, IGWs without traffic, and S3 gateway endpoints have no provisioned hourly charge. No public IPv4 address is allocated. [S3 gateway endpoint pricing/behavior](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints-s3.html). Same-AZ private peering traffic has no cross-AZ transfer in this layout; moving a workload to another AZ changes the transfer assumptions. [EC2 data transfer pricing](https://aws.amazon.com/ec2/pricing/on-demand/).

T3 uses **standard** credits to avoid unlimited-mode surplus-credit charges; sustained CPU can instead be throttled. CloudWatch basic EC2 metrics remain at default settings. SSM standard Session Manager use for EC2 does not introduce an advanced on-premises instance tier here. Optional session logging, KMS customer keys, packet-analysis services, remote state storage, snapshots, or expanded monitoring have separate costs.

Stopping instances leaves disks, endpoints, hosted zone and log storage provisioned. Destroy the lab after practice. Inspect Billing/Cost Explorer after its usage reporting delay and search by `LabId`, noting that not all charges have immediate resource-level tagging. Set a sandbox budget/alerts manually if desired, but **budget alerts are not spending caps** and can be delayed. This repository does not create a budget or guarantee any maximum bill.

```bash
python3 scripts/lab.py evidence
python3 scripts/lab.py destroy --approve
python3 scripts/lab.py verify-destroy
```
