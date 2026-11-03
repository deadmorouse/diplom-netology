#!/usr/bin/env bash
# Print presence/status only; never print credential values.
set -eu
sudo -n -H -u github-runner python3 - <<'PY'
from pathlib import Path
import json
home=Path.home()
for name in ['.docker/config.json','.kube/config','.ssh/id_ed25519','.ssh/id_rsa']:
    path=home/name
    print(name, 'present' if path.is_file() else 'absent')
    if name=='.docker/config.json' and path.is_file():
        data=json.loads(path.read_text())
        print('Registry names:',list(data.get('auths',{})))
        print('Credential helper configured:',bool(data.get('credsStore') or data.get('credHelpers')))
        print('Credentials present:',any(bool(v.get('auth') or v.get('identitytoken')) for v in data.get('auths',{}).values()))
PY
sudo -n python3 - <<'PY'
from pathlib import Path
import re
logs=sorted(Path('/home/github-runner/actions-runner/_diag').glob('Runner_*.log'))
if logs:
    path=logs[-1]
    print('Latest runner log:',path.name)
    text=path.read_text(errors='replace')
    markers=['Listening for Jobs','Connected to GitHub','Running job:','Job completed with result:','401','403']
    for marker in markers:
        matching=[line for line in text.splitlines() if marker in line]
        print(marker, 'count:',len(matching))
        if matching:
            timestamp=re.search(r'\d{4}-\d{2}-\d{2}[^\]]*',matching[-1])
            print('Last timestamp:',timestamp.group(0)[:35] if timestamp else 'not found')
PY
