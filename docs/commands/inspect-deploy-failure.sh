#!/usr/bin/env bash
# Select diagnostic lines only; do not dump environment or credentials.
set -eu
sudo -n python3 - <<'PY'
from pathlib import Path
import re
root=Path('/home/github-runner/actions-runner')
logs=sorted((root/'_diag').glob('Worker_*.log'))
if logs:
    p=logs[-1]
    print('Worker log:',p.name)
    content=p.read_text(errors='replace')
    print('Image digests in job message:', sorted(set(re.findall(r'(?:docker.io/)?iksok/test-nginx-app@sha256:[0-9a-f]+', content))))
    lines=content.splitlines()
    for i,line in enumerate(lines):
        if '"lit": "DEPLOY_IMAGE"' in line:
            print('DEPLOY_IMAGE value structure:')
            for following in lines[i+1:i+9]:
                print(following[:250])
    markers=['Unable to connect', 'connection refused', 'certificate has expired',
             'x509:', 'Process completed with exit code', 'Process exited with code',
             'kubectl', 'hostname -s', 'DEPLOY_IMAGE', 'error:']
    for line in p.read_text(errors='replace').splitlines():
        if any(m in line for m in markers) and not any(s in line.lower() for s in ['token','password','authorization','credential']):
            print(line[:700])
envfile=root/'.env'
if envfile.exists():
    for line in envfile.read_text().splitlines():
        if line.startswith(('HOME=','KUBECONFIG=')):
            print('Runner env:',line)
PY
hostname -s
sudo -n -H -u github-runner kubectl --request-timeout=10s get nodes
