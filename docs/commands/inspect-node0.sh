#!/usr/bin/env bash
# Read-only inspection. Never print private keys, tokens or Docker auth values.
set -u
printf 'Host: '; hostname
id
printf '\nRunner services:\n'
systemctl list-units --all --type=service 'actions.runner.*' --no-pager
printf '\nInstalled tools:\n'
for tool in git gh docker kubectl terraform helm; do command -v "$tool" || true; done
python3 - <<'PY'
from pathlib import Path
import json, os, subprocess, urllib.parse
roots=[Path('/home/ubuntu'),Path('/opt')]
skip={'.cache','.local','.npm','.git','node_modules','_work','_diag','.terraform','.venv'}
for root in roots:
    for directory,dirs,files in os.walk(root):
        depth=len(Path(directory).relative_to(root).parts)
        dirs[:]=[d for d in dirs if d not in skip] if depth<5 else []
        path=Path(directory)
        if '.runner' in files:
            data=json.loads((path/'.runner').read_text())
            print('Runner directory:',path)
            print('Runner metadata:',{k:data.get(k) for k in ['agentName','gitHubUrl','workFolder','disableUpdate']})
            binary=path/'bin/Runner.Listener'
            if binary.is_file():
                result=subprocess.run([str(binary),'--version'],capture_output=True,text=True,timeout=15)
                print('Runner version:',result.stdout.strip())
        if (path/'.git').is_dir():
            result=subprocess.run(['git','-C',str(path),'config','--get-regexp',r'^remote\..*\.url$'],capture_output=True,text=True)
            print('Git checkout:',path)
            for line in result.stdout.splitlines():
                name,url=line.split(None,1)
                if '://' in url:
                    p=urllib.parse.urlsplit(url);url=urllib.parse.urlunsplit((p.scheme,p.hostname or '',p.path,'',''))
                print(name,url)
docker=Path.home()/'.docker/config.json'
if docker.is_file():
    data=json.loads(docker.read_text())
    print('Docker credential registry names:',list(data.get('auths',{})))
    print('Docker credential helper configured:',bool(data.get('credsStore') or data.get('credHelpers')))
for variable in ['GH_TOKEN','GITHUB_TOKEN','KUBECONFIG']:
    print(variable,'present' if os.environ.get(variable) else 'absent')
PY
printf '\nSSH public-key fingerprints:\n'
for path in "$HOME"/.ssh/*.pub "$HOME"/.ssh/authorized_keys; do
  if [ -f "$path" ]; then printf '%s\n' "$path"; ssh-keygen -lf "$path"; fi
done
printf '\nDocker access as ubuntu:\n'
docker version --format '{{.Server.Version}}' 2>&1
printf '\nKubernetes access as ubuntu:\n'
kubectl config current-context 2>&1
kubectl --request-timeout=10s get nodes 2>&1
kubectl --request-timeout=10s auth can-i patch deployments -n test-app 2>&1
printf '\nKubernetes client certificate dates (certificate only):\n'
kubectl config view --raw --minify -o 'jsonpath={.users[0].user.client-certificate-data}' 2>/dev/null | base64 -d | openssl x509 -noout -dates -subject 2>&1
printf '\nApplication image and rollout:\n'
sudo -n kubectl --kubeconfig=/etc/kubernetes/admin.conf --request-timeout=10s -n test-app get deployment nginx-app -o 'custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[0].image,READY:.status.readyReplicas'
