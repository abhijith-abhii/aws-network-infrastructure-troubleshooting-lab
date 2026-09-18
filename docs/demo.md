# Five-minute demonstration

Prepare a live, healthy lab before the presentation. Run the five-scenario suite and collect evidence separately; the full suite cannot responsibly fit into five minutes because AWS propagation and DNS caching take time. This script uses one live routing failure and real, previously collected examples for the others. Label any screenshot with its capture date; if you have not deployed, demonstrate code/static tests only and say so.

| Time | What to show / say |
|---|---|
| 0:00–0:40 | “This is my personal AWS networking lab. A private client in one VPC calls a private service in another. Both remain manageable without public IPs or SSH.” Show the diagram and /24 routes. |
| 0:40–1:30 | Show `python3 scripts/lab.py test`: HTTP by name/IP, S3 from both instances, local listener, and blocked SSH/reverse HTTP. Describe the expected page/object text. |
| 1:30–2:30 | Run `python3 scripts/lab.py inject routing --approve`. Explain that the plan is allowed to remove only one route, then compare the failing HTTP test with working DNS, S3 and SSM. If apply is slow, show the actual previously captured route evidence and explain the delay. |
| 2:30–3:20 | Show `ip route get` versus the AWS route table: the guest's gateway is healthy but the cloud route is missing. Explain why a timeout or missing flow record alone is not a diagnosis. |
| 3:20–4:10 | Run `python3 scripts/lab.py restore --approve`. Show the route recreated and baseline recovery. Use real saved test output if live propagation is still in progress; never pretend pending output passed. |
| 4:10–4:40 | Show evidence from NACL directionality, DNS NXDOMAIN, and the S3 explicit deny. Explain why the last two need evidence other than Flow Logs. |
| 4:40–5:00 | Show static CI, cost estimate and teardown command. “This is single-AZ and deliberately small. I verify removal and check delayed billing after each session.” |

After the demo, run `python3 scripts/lab.py evidence`, `python3 scripts/lab.py destroy --approve`, then `python3 scripts/lab.py verify-destroy`. If the live exercise fails unexpectedly, show the observed state and investigate; do not force a rehearsed conclusion.
