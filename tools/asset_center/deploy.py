#!/usr/bin/env python3
"""Deploy the asset center using the official InstaBox CLI."""
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
STATE = ROOT / ".scratch" / "instabox"
CONFIG = ROOT / ".env.instabox"
REMOTE = "/data/home/jiuding-asset-center"
MACHINE = "m_agqxzavig73nnfofr6sxgvcvka"
DATA_DIR = Path("docs/art/美术资产库_v0.1")
DATA_FILES = ["资产总表.json", "资产总表.csv", "资产分类目录.md"]
MEDIA_SUFFIXES = {".png", ".webp", ".jpg", ".jpeg", ".svg"}


def collect_files(root):
    files = list((root / "tools/asset_center").glob("*.py"))
    files += list((root / "tools/asset_center/web").glob("*"))
    files += [root / "godot/scripts/alpha/alpha_state.gd"]
    for folder in ("assets", "output/art"):
        files += [p for p in (root / folder).rglob("*")
                  if p.is_file() and p.suffix.lower() in MEDIA_SUFFIXES]
    selected = {}
    for path in sorted(files):
        if not path.is_file() or path.is_symlink():
            continue
        selected[path.relative_to(root).as_posix()] = path
    return selected


def cli(args, env, capture=False, stdin=None):
    result = subprocess.run(
        [env["INSTABOX_BIN"], *args], env=env, text=True,
        input=stdin, stdout=subprocess.PIPE if capture else None, check=True,
    )
    return result.stdout if capture else None


def remote_command(command, env, stdin=None):
    output = cli(["exec", MACHINE, "--timeout", "120", "--json",
                  *(["--stdin"] if stdin is not None else []), "--", command],
                 env, capture=True, stdin=stdin)
    result = json.loads(output)
    if result.get("exitCode") != 0:
        raise RuntimeError(result.get("stderr") or result.get("stdout") or str(result))
    return result["stdout"]


def verify_public(url, config):
    import base64
    from urllib.error import HTTPError
    try:
        urllib.request.urlopen(url + "/api/data", timeout=60)
    except HTTPError as error:
        if error.code != 401:
            raise
    else:
        raise RuntimeError("Public API is missing authentication")
    token = base64.b64encode(
        f"{config['username']}:{config['password']}".encode()
    ).decode()
    request = urllib.request.Request(
        url + "/api/data", headers={"Authorization": "Basic " + token})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = json.load(response)
    if not data["assets"]:
        raise RuntimeError("Public dataset is empty")
    print(f"HTTPS authentication and data verified: {len(data['assets'])} assets")


def main():
    STATE.mkdir(parents=True, exist_ok=True)
    if not CONFIG.exists():
        config = {"api_key": "", "username": "admin",
                  "password": secrets.token_urlsafe(24)}
        descriptor = os.open(CONFIG, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w") as stream:
            json.dump(config, stream, indent=2)
    config = json.loads(CONFIG.read_text())
    CONFIG.chmod(0o600)
    env = os.environ.copy()
    if config.get("api_key"):
        env["INSTABOX_API_KEY"] = config["api_key"]
    if not env.get("INSTABOX_API_KEY"):
        raise RuntimeError(f"Set api_key in {CONFIG}, or export INSTABOX_API_KEY")
    if not config.get("password") or not config.get("username"):
        raise RuntimeError("Deployment username and password must not be empty")
    for field in ("username", "password"):
        if any(c in config[field] for c in "\r\n\"'\\%$"):
            raise RuntimeError(f"{field} contains an unsupported environment-file character")
    env["INSTABOX_BIN"] = (
        env.get("INSTABOX_BIN") or shutil.which("instabox") or str(STATE / "instabox"))
    if not Path(env["INSTABOX_BIN"]).is_file():
        raise RuntimeError("Install the official instabox CLI, then run again")

    machine = json.loads(cli(["get", MACHINE, "--json"], env, capture=True))
    state = machine.get("state", machine.get("status"))
    if state in ("paused", "suspended"):
        cli(["resume", MACHINE], env)
    elif state == "stopped":
        cli(["start", MACHINE], env)
    elif state != "running":
        raise RuntimeError(f"Machine is not ready: {state}")

    remote_state = json.loads(remote_command(
        "python3 -c 'import json; from pathlib import Path; "
        f"p=Path(\"{REMOTE}\"); (p/\"incoming\").mkdir(parents=True, exist_ok=True); "
        "m=p/\"deployed-manifest.json\"; "
        f"d=p/\"workspace\"/\"{DATA_DIR.as_posix()}\"/\"{DATA_FILES[0]}\"; "
        "print(json.dumps({\"manifest\":json.loads(m.read_text()) if m.exists() else {},"
        "\"seed\":not d.exists()}))'", env))
    files = collect_files(ROOT)
    print(f"Checking {len(files)} code/media files...", flush=True)
    manifest = {}
    for name, path in files.items():
        with path.open("rb") as stream:
            manifest[name] = hashlib.file_digest(stream, "sha256").hexdigest()
    changed = [name for name in files if manifest[name] != remote_state["manifest"].get(name)]
    print(f"Uploading {len(changed)} changed files; existing server records are preserved.", flush=True)

    with tempfile.TemporaryDirectory(dir=STATE) as temp:
        temp = Path(temp)
        archive = temp / "release.tar"
        with tarfile.open(archive, "w") as bundle:
            for name in changed:
                bundle.add(files[name], arcname=name, recursive=False)
            if remote_state["seed"]:
                for name in DATA_FILES:
                    path = ROOT / DATA_DIR / name
                    bundle.add(path, arcname=str(Path(".seed") / DATA_DIR / name))
            manifest_path = temp / "manifest.json"
            manifest_path.write_text(json.dumps(manifest))
            bundle.add(manifest_path, arcname=".release-manifest.json")
        cli(["push", MACHINE, str(archive), REMOTE + "/incoming/release.tar"], env)

        published = json.loads(cli(
            ["port", "publish", MACHINE, "8899", "--name", "Jiuding Asset Center", "--json"],
            env, capture=True))
        url = published["url"].rstrip("/")
        service_env = temp / "service.env"
        service_env.write_text(
            "ASSET_CENTER_AUTH_REQUIRED=1\nASSET_CENTER_HOST=0.0.0.0\n"
            f"ASSET_CENTER_USERNAME={config['username']}\n"
            f"ASSET_CENTER_PASSWORD={config['password']}\n"
            f"ASSET_CENTER_PUBLIC_ORIGIN={url}\n")
        service_env.chmod(0o600)
        cli(["push", MACHINE, str(service_env), REMOTE + "/incoming/service.env"], env)
        installer = (ROOT / "tools/asset_center/install.sh").read_text()
        print(remote_command("bash -s", env, stdin=installer), end="", flush=True)
    verify_public(url, config)
    (STATE / "deployment.json").write_text(json.dumps(
        {"machine": MACHINE, "url": url, "changed_files": len(changed)}, indent=2))
    print(f"Deployment complete: {url}\nLogin: {config['username']}\nPassword: stored in {CONFIG}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"Deployment failed: {error}", file=sys.stderr)
        sys.exit(1)
