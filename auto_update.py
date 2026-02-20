#!/usr/bin/env python3
"""
Auto-Update System — GitHub Edition
Fetches the skills manifest from GitHub and installs any updates.
Source of truth: https://github.com/hamnhugs/bookworm-studio (bot-manifest/manifest.json)
"""

import sys
import json
import subprocess
import urllib.request
from pathlib import Path
from datetime import datetime

# GitHub raw URL for the manifest
MANIFEST_URL = "https://raw.githubusercontent.com/hamnhugs/bot-manifest/main/manifest.json"
MANIFEST_FILE = Path.home() / ".openclaw/workspace/skills/bot-deployer/manifest.json"
LOG_FILE = Path.home() / ".openclaw/workspace/memory/auto_update.log"

def log(message):
    """Log with timestamp"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_message = f"[{timestamp}] {message}"
    print(log_message)
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG_FILE, 'a') as f:
        f.write(log_message + "\n")

def compare_versions(v1: str, v2: str) -> int:
    """Compare two semantic versions. Returns 1 if v1>v2, -1 if v1<v2, 0 if equal."""
    try:
        parts1 = [int(x) for x in v1.split('.')]
        parts2 = [int(x) for x in v2.split('.')]
        while len(parts1) < len(parts2): parts1.append(0)
        while len(parts2) < len(parts1): parts2.append(0)
        for p1, p2 in zip(parts1, parts2):
            if p1 > p2: return 1
            elif p1 < p2: return -1
        return 0
    except:
        return 0

def get_installed_version(skill_name: str) -> str:
    """Get currently installed version of a skill."""
    version_file = Path.home() / ".openclaw/workspace/skills" / skill_name / ".version"
    if version_file.exists():
        try:
            return version_file.read_text().strip()
        except:
            pass
    return "0.0.0"

MANIFEST_API_URL = "https://api.github.com/repos/hamnhugs/bot-manifest/contents/manifest.json"

def fetch_manifest_from_github() -> dict:
    """Fetch the latest manifest from GitHub (raw CDN with API fallback)."""
    import base64

    # Try raw CDN first (fastest)
    for url, use_api in [(MANIFEST_URL, False), (MANIFEST_API_URL, True)]:
        try:
            req = urllib.request.Request(
                url,
                headers={"User-Agent": "OpenClaw-Bot-Updater/1.0",
                         "Accept": "application/vnd.github.v3+json" if use_api else "*/*"}
            )
            with urllib.request.urlopen(req, timeout=30) as response:
                data = response.read().decode("utf-8")
                if use_api:
                    # GitHub API returns base64-encoded content
                    api_resp = json.loads(data)
                    content  = base64.b64decode(api_resp["content"]).decode("utf-8")
                    return json.loads(content)
                else:
                    return json.loads(data)
        except Exception as e:
            log(f"⚠️  {'CDN' if not use_api else 'API'} fetch failed: {e} — {'trying API fallback...' if not use_api else 'giving up'}")

    return None

def check_for_updates(dry_run=False, auto_install=False):
    """Fetch manifest from GitHub and install any updated or new skills."""
    log("🔄 Fetching manifest from GitHub...")
    log(f"   URL: {MANIFEST_URL}")

    remote_manifest = fetch_manifest_from_github()
    if not remote_manifest:
        log("❌ Could not fetch remote manifest — check internet connection")
        return False

    remote_version = remote_manifest.get("version", "unknown")
    remote_updated = remote_manifest.get("updated", "unknown")
    remote_model   = remote_manifest.get("model", "")
    log(f"✅ Remote manifest: v{remote_version} ({remote_updated})")

    # Load local manifest if it exists
    local_manifest = {}
    if MANIFEST_FILE.exists():
        try:
            with open(MANIFEST_FILE) as f:
                local_manifest = json.load(f)
            log(f"   Local  manifest: v{local_manifest.get('version','?')} ({local_manifest.get('updated','?')})")
        except:
            log("   Local manifest unreadable — will overwrite")
    else:
        log("   No local manifest found — fresh install")

    # ── Model check ──────────────────────────────────────────────────────────
    if remote_model:
        config_path = Path.home() / ".openclaw/openclaw.json"
        if config_path.exists():
            try:
                cfg = json.loads(config_path.read_text())
                current_model = cfg.get("agents", {}).get("defaults", {}).get("model", {}).get("primary", "")
                if current_model != remote_model:
                    log(f"⚠️  Model mismatch: local={current_model}  remote={remote_model}")
                    log(f"   Run safe-model-switch to upgrade to {remote_model}")
                else:
                    log(f"✅ Model up to date: {current_model}")
            except:
                pass

    # ── Skill version check ───────────────────────────────────────────────────
    remote_skills   = remote_manifest.get("skills", [])
    local_skills_map = {s.get("name"): s for s in local_manifest.get("skills", [])}
    skills_to_update = []

    log("\n📚 Checking skill versions...")
    for skill in remote_skills:
        name           = skill.get("name")
        remote_ver     = skill.get("version", "1.0.0")
        local_ver      = local_skills_map.get(name, {}).get("version", "0.0.0")
        installed_ver  = get_installed_version(name)
        effective_local = max([local_ver, installed_ver],
                              key=lambda v: [int(x) for x in v.split(".")])

        cmp = compare_versions(remote_ver, effective_local)
        if cmp > 0:
            log(f"   ⬆️  {name}: v{effective_local} → v{remote_ver}")
            skills_to_update.append(name)
        elif cmp < 0:
            log(f"   ⬇️  {name}: v{effective_local} (local is newer)")
        else:
            log(f"   ✅ {name}: v{effective_local}")

    # New skills not in local manifest
    new_skills = set(s.get("name") for s in remote_skills) - set(local_skills_map)
    for name in new_skills:
        if name not in skills_to_update:
            log(f"   🆕 {name}: new skill available")
            skills_to_update.append(name)

    if not skills_to_update:
        log("\n✅ All skills up to date!")
        # Still save/refresh manifest
        if not dry_run:
            MANIFEST_FILE.parent.mkdir(parents=True, exist_ok=True)
            with open(MANIFEST_FILE, "w") as f:
                json.dump(remote_manifest, f, indent=2)
        return False

    log(f"\n✨ {len(skills_to_update)} skill(s) need updating: {', '.join(skills_to_update)}")

    if dry_run:
        log("   (Dry run — not applying changes)")
        return True

    # ── Save updated manifest ─────────────────────────────────────────────────
    MANIFEST_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(MANIFEST_FILE, "w") as f:
        json.dump(remote_manifest, f, indent=2)
    log(f"✅ Manifest saved: v{remote_version}")

    # ── Auto-install ──────────────────────────────────────────────────────────
    if auto_install:
        log("\n🚀 Auto-installing updated skills...")
        install_script = Path.home() / ".openclaw/workspace/skills/bot-deployer/scripts/install_skills.py"
        if install_script.exists():
            result = subprocess.run(
                ["python3", str(install_script)],
                capture_output=True, text=True, timeout=300
            )
            log(result.stdout)
            if result.returncode == 0:
                log("✅ Skills installed successfully")
            else:
                log(f"⚠️  Installation errors: {result.stderr}")
        else:
            log("⚠️  install_skills.py not found — manual install required")
    else:
        log("\n📋 To install, run:")
        log("   python3 ~/.openclaw/workspace/skills/bot-deployer/scripts/install_skills.py")

    return True

def main():
    dry_run      = "--dry-run"      in sys.argv
    auto_install = "--auto-install" in sys.argv

    if "--help" in sys.argv or "-h" in sys.argv:
        print("Usage:")
        print("  python3 auto_update.py                 # Check for updates")
        print("  python3 auto_update.py --auto-install  # Check + install")
        print("  python3 auto_update.py --dry-run       # Check only, no changes")
        print(f"\n  Manifest source: {MANIFEST_URL}")
        return

    log("=" * 60)
    log("BOT AUTO-UPDATE  (GitHub Edition)")
    log("=" * 60)

    updated = check_for_updates(dry_run=dry_run, auto_install=auto_install)

    if updated and not dry_run:
        log("\n✅ Update complete! Restart may be required.")

    log("=" * 60)

if __name__ == "__main__":
    main()
