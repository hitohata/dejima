"""Merge the managed local DNS rewrite while the AdGuard container is stopped."""

import os
from pathlib import Path
import shutil
import sys
import tempfile

import yaml


def configure(path):
    if not path.is_file():
        raise SystemExit(
            "Restore the existing AdGuardHome.yaml before starting AdGuard; "
            "this migration does not create administrator credentials."
        )

    original = path.read_text()
    config = yaml.safe_load(original)
    if not isinstance(config, dict):
        raise SystemExit("Expected an AdGuard configuration mapping; left unchanged.")

    filtering = config.setdefault("filtering", {})
    rewrites = filtering.get("rewrites") or []
    # Preserve explicit host overrides and unrelated domains. This wildcard is
    # owned by Nix and will be restored on every container start.
    managed = {
        "domain": "*.dejima.men",
        "answer": "192.168.60.1",
        "enabled": True,
    }
    updated = [r for r in rewrites if r["domain"] != managed["domain"]] + [managed]
    if updated == rewrites:
        return
    filtering["rewrites"] = updated

    # Keep the first pre-migration configuration, including ownership and mode.
    metadata = path.stat()
    backup = path.with_name(path.name + ".before-local-dns")
    if not backup.exists():
        shutil.copy2(path, backup)
        os.chown(backup, metadata.st_uid, metadata.st_gid)

    # An interrupted write must not leave AdGuard with a partial configuration.
    fd, temporary = tempfile.mkstemp(prefix=".AdGuardHome-", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            os.fchown(output.fileno(), metadata.st_uid, metadata.st_gid)
            os.fchmod(output.fileno(), metadata.st_mode & 0o777)
            yaml.safe_dump(config, output, sort_keys=False)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    configure(Path(sys.argv[1]))
