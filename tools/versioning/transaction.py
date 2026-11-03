"""Recoverable multi-file metadata publication (not filesystem-wide atomicity)."""
import base64
import json
import os
from pathlib import Path

JOURNAL = ".release-transaction.json"


def recover(root):
    root = Path(root)
    journal = root / JOURNAL
    data = json.loads(journal.read_text())
    if set(data) != {"VERSION", "CHANGELOG.md", "project.godot"}:
        raise ValueError("Invalid recovery journal; inspect manually")
    for name, original in data.items():
        path = root / name
        if original is None:
            path.unlink(missing_ok=True)
        else:
            temporary = root / (name + ".release-tmp")
            temporary.write_bytes(base64.b64decode(original, validate=True))
            os.replace(temporary, path)
        (root / (name + ".release-tmp")).unlink(missing_ok=True)
    journal.unlink()


def publish(root, changes):
    root = Path(root)
    journal = root / JOURNAL
    if journal.exists(): raise ValueError("Interrupted release: run recover before preparing again")
    if set(changes) != {"VERSION", "CHANGELOG.md", "project.godot"}:
        raise ValueError("Unexpected release metadata paths")
    originals = {name: base64.b64encode((root / name).read_bytes()).decode() if (root / name).exists() else None for name in changes}
    # Exclusive journal creation prevents silently replacing a recovery record.
    with journal.open("x") as file:
        json.dump(originals, file)
        file.flush()
        os.fsync(file.fileno())
    try:
        for name, text in changes.items():
            temporary = root / (name + ".release-tmp")
            with temporary.open("w") as file:
                file.write(text)
                file.flush()
                os.fsync(file.fileno())
            os.replace(temporary, root / name)
    except OSError:
        recover(root)
        raise
    journal.unlink()
