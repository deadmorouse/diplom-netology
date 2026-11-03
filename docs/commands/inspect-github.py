"""Read public GitHub metadata and resolve action tags; no authentication."""
import json
import urllib.request

def get(path):
    request = urllib.request.Request(
        "https://api.github.com/" + path,
        headers={"Accept": "application/vnd.github+json", "User-Agent": "diploma-ci-check"},
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)

repo = get("repos/deadmorouse/diplom-netology")
print("Repository:", json.dumps({key: repo.get(key) for key in
      ["full_name", "private", "default_branch", "size", "html_url", "archived"]}))
for action, tag in [("actions/checkout", "v6"), ("hashicorp/setup-terraform", "v4")]:
    obj = get(f"repos/{action}/git/ref/tags/{tag}")["object"]
    while obj["type"] == "tag":
        obj = get(f"repos/{action}/git/tags/{obj['sha']}")["object"]
    print("Action:", action, tag, obj["sha"])
