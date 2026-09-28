# Data, code and model sources

The topic comes from the source mapping in the portfolio index. Original authored synthetic fixtures and procedural images are distributed under the repository MIT license. Synthetic records do not describe actual customers, employees, players or transactions.

Implementation references:
- Flask: https://flask.palletsprojects.com/en/stable/ — request handling and security considerations.
- Python SQLite: https://docs.python.org/3/library/sqlite3.html — transactions, parameter binding and authorizers.
- scikit-learn: https://scikit-learn.org/stable/common_pitfalls.html — leakage prevention and fitted preprocessing.

Only applicable libraries are used; their upstream licenses remain in installed distributions. Project code does not claim authorship of dependencies.

Terraform tests: https://developer.hashicorp.com/terraform/language/tests/mocking
Kubernetes HPA: https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
GitHub Actions containers: https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images
Selection rationale: CNCF 2025 annual survey, https://www.cncf.io/announcements/2026/01/20/kubernetes-established-as-the-de-facto-operating-system-for-ai-as-production-use-hits-82-in-2025-cncf-annual-cloud-native-survey/ . This indicates technology adoption, not a promise of entry-level hiring demand.
