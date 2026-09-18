# CloudWatch Logs Insights

Select the exact log group from `python3 scripts/lab.py inventory`, normally `/personal-lab/aws-netlab/vpc-flow`. Set the time range to the exercise interval plus a buffer (e.g. last 30 minutes). The lab uses the standard 14-field Flow Log format with 60-second maximum aggregation. Publication is asynchronous and best-effort; the integration check polls up to 15 minutes. No record is not proof of no traffic.

Explicit parsing keeps these queries independent of automatic field discovery. Replace IPs if you intentionally redesign the address plan. These are query definitions, not captured results.

## HTTP in both directions

```sql
fields @timestamp, @message
| parse @message "* * * * * * * * * * * * * *" as ver, accountId, interfaceId, srcAddr, dstAddr, srcPort, dstPort, proto, packets, flowBytes, startSec, endSec, action, logStatus
| filter logStatus = "OK" and proto = "6"
| filter (srcAddr = "10.10.10.10" and dstAddr = "10.20.10.10") or (srcAddr = "10.20.10.10" and dstAddr = "10.10.10.10")
| filter srcPort = "80" or dstPort = "80"
| sort @timestamp desc
| limit 100
```

## Rejected traffic grouped by tuple

```sql
parse @message "* * * * * * * * * * * * * *" as ver, accountId, interfaceId, srcAddr, dstAddr, srcPort, dstPort, proto, packets, flowBytes, startSec, endSec, action, logStatus
| filter logStatus = "OK" and action = "REJECT"
| stats count(*) as records, sum(flowBytes) as bytes by interfaceId, srcAddr, dstAddr, srcPort, dstPort, proto
| sort records desc
```

A REJECT does not identify the exact SG or ACL rule. The blocked SSH/reverse-HTTP control probes also intentionally create rejects even in a healthy baseline; filter to the HTTP forward/return tuple when investigating a fault.

## Server HTTP return-path rejects

```sql
parse @message "* * * * * * * * * * * * * *" as ver, accountId, interfaceId, srcAddr, dstAddr, srcPort, dstPort, proto, packets, flowBytes, startSec, endSec, action, logStatus
| filter srcAddr = "10.20.10.10" and dstAddr = "10.10.10.10" and srcPort = "80" and action = "REJECT"
| display @timestamp, interfaceId, srcPort, dstPort, packets, action, logStatus
| sort @timestamp desc
```

## Delivery and sampling health

```sql
parse @message "* * * * * * * * * * * * * *" as ver, accountId, interfaceId, srcAddr, dstAddr, srcPort, dstPort, proto, packets, flowBytes, startSec, endSec, action, logStatus
| stats count(*) as records by interfaceId, logStatus, bin(5m)
```

`NODATA` means no captured traffic for the interval, `SKIPDATA` means some records were skipped, and `OK` is a recorded flow. The script requires recent OK records from both **workload ENIs**, not simply that the group exists. A source/destination ENI can each produce a record; summed bytes across both are not necessarily unique application bytes.

SSM management traffic goes to local interface ENIs on TCP/443. S3 uses regional service addresses and a gateway route; it has no gateway endpoint ENI. AmazonProvidedDNS, DHCP and certain platform traffic are excluded. Flow Logs contain neither DNS answers nor S3 authorization reasons. Use `dig`/Route 53 configuration for DNS, and API errors plus actual policies for S3. See [AWS limitations](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs-limitations.html).
