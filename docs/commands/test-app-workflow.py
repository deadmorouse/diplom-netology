#!/usr/bin/env python3
"""Run the actual build and smoke-test commands from app.yml locally."""
import os
from pathlib import Path
import subprocess
import tempfile
import yaml

workflow = yaml.safe_load(Path('.github/workflows/app.yml').read_text())
with tempfile.TemporaryDirectory(prefix='diploma-app-check-') as directory:
    env = dict(os.environ, IMAGE='diploma-nginx-check', GITHUB_SHA='local',
               GITHUB_SERVER_URL='https://github.com',
               GITHUB_REPOSITORY='deadmorouse/diplom-netology', RUNNER_TEMP=directory)
    for step in workflow['jobs']['build']['steps']:
        if step.get('name') in ['Build image', 'Test Nginx configuration and HTTP response']:
            print(step['name'], flush=True)
            subprocess.run(['bash', '-e', '-o', 'pipefail', '-c', step['run']],
                           env=env, check=True)
