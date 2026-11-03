#!/usr/bin/env bash
# Read-only checks. No credentials are printed.
set -eu
unit=actions.runner.deadmorouse-diplom-netology.node-0.service
systemctl show "$unit" -p ActiveState -p SubState -p User
sudo -n -H -u github-runner kubectl --request-timeout=10s get nodes
sudo -n -H -u github-runner kubectl --request-timeout=10s -n test-app get deployment nginx-app -o wide
sudo -n python3 - <<'PY'
from pathlib import Path
import subprocess
result = subprocess.run(['journalctl', '-u', 'actions.runner.deadmorouse-diplom-netology.node-0.service', '-n', '150', '--no-pager'], capture_output=True, text=True)
for line in result.stdout.splitlines():
    if any(marker in line for marker in ['Connected to GitHub', 'Listening for Jobs', 'Running job:', 'Job completed', 'HTTP status code:']):
        print(line)
PY
