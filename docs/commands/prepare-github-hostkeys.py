#!/usr/bin/env python3
"""Fetch GitHub's public SSH host keys over HTTPS into a temporary known_hosts."""
import json
from pathlib import Path
import urllib.request

request = urllib.request.Request('https://api.github.com/meta',
                                 headers={'User-Agent': 'diploma-cicd-check'})
with urllib.request.urlopen(request, timeout=20) as response:
    keys = json.load(response)['ssh_keys']
if not keys or not all(key.startswith(('ssh-ed25519 ', 'ssh-rsa ', 'ecdsa-sha2-nistp256 ')) for key in keys):
    raise SystemExit('Unexpected SSH host key response')
target = Path('/tmp/diploma-github-known-hosts')
target.write_text(''.join(f'github.com {key}\n' for key in keys))
target.chmod(0o600)
print('Saved official public GitHub host keys:', target)
