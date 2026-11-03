#!/usr/bin/env bash
set -eu
unit=actions.runner.deadmorouse-diplom-netology.node-0.service
systemctl show "$unit" -p User -p WorkingDirectory -p ActiveState -p SubState
runner_user=$(systemctl show "$unit" -p User --value)
runner_user=${runner_user:-root}
runner_dir=$(systemctl show "$unit" -p WorkingDirectory --value)
sudo -n -u "$runner_user" id
sudo -n python3 - "$runner_dir" <<'PY'
from pathlib import Path
import json,sys,subprocess,urllib.parse
root=Path(sys.argv[1])
data=json.loads((root/'.runner').read_text(encoding='utf-8-sig'))
print('Runner:',{k:data.get(k) for k in ['agentName','gitHubUrl','workFolder','disableUpdate']})
print('Registration credentials present:',(root/'.credentials').is_file())
print('Runner version:',subprocess.run([str(root/'bin/Runner.Listener'),'--version'],capture_output=True,text=True).stdout.strip())
work=root/data.get('workFolder','_work')
for git in work.glob('*/*/.git'):
    repo=git.parent
    print('Checkout:',repo)
    result=subprocess.run(['git','-C',str(repo),'config','--get-regexp',r'^remote\..*\.url$'],capture_output=True,text=True)
    for line in result.stdout.splitlines():
        name,url=line.split(None,1)
        if '://' in url:
            p=urllib.parse.urlsplit(url);url=urllib.parse.urlunsplit((p.scheme,p.hostname or '',p.path,'',''))
        print(name,url)
    print('Workflow files:',[p.name for p in (repo/'.github/workflows').glob('*')])
    print('Current commit:',subprocess.run(['git','-C',str(repo),'rev-parse','HEAD'],capture_output=True,text=True).stdout.strip())
PY
printf '\nRunner Docker access:\n'
sudo -n -H -u "$runner_user" docker version --format '{{.Server.Version}}' || true
printf '\nRunner Kubernetes access:\n'
sudo -n -H -u "$runner_user" kubectl --request-timeout=10s get nodes || true
sudo -n -H -u "$runner_user" kubectl --request-timeout=10s auth can-i patch deployments -n test-app || true
printf '\nRunner Kubernetes client certificate (dates only):\n'
sudo -n -H -u "$runner_user" kubectl config view --raw --minify -o 'jsonpath={.users[0].user.client-certificate-data}' 2>/dev/null | base64 -d | openssl x509 -noout -dates -subject || true
printf '\nCluster certificate validity:\n'
sudo -n kubeadm certs check-expiration --cert-dir=/etc/kubernetes/ssl 2>&1
