#!/usr/bin/env python3
"""Show public workflow/job statuses without requesting or printing secrets."""
import json
import urllib.request

base = 'https://api.github.com/repos/deadmorouse/diplom-netology'

def get(path):
    request = urllib.request.Request(base + path, headers={'User-Agent': 'diploma-cicd-check'})
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)

for run in get('/actions/runs?per_page=6')['workflow_runs']:
    print(json.dumps({key: run.get(key) for key in
                     ['id', 'name', 'event', 'head_branch', 'head_sha', 'status', 'conclusion', 'html_url']}, ensure_ascii=False))
    for job in get(f"/actions/runs/{run['id']}/jobs")['jobs']:
        print(' Job:', job['name'], job['status'], job['conclusion'], job.get('runner_name'))
        for step in job.get('steps', []):
            if step.get('conclusion') == 'failure':
                print(' Failed step:', step['name'])
