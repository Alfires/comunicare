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
    # Validate the entire journal before restoring any file. Never follow a
    # symlink supplied by a damaged or manually edited repository.
    decoded = {}
    for name, original in data.items():
        if (root / name).is_symlink() or (root / (name + ".release-tmp")).is_symlink():
            raise ValueError("Recovery path is linked; inspect manually")
        if original is not None and not isinstance(original, str):
            raise ValueError("Invalid recovery data")
        decoded[name] = base64.b64decode(original, validate=True) if original is not None else None
    for name, original in decoded.items():
        path = root / name
        if original is None:
            path.unlink(missing_ok=True)
        else:
            temporary = root / (name + ".release-tmp")
            temporary.write_bytes(original)
            os.replace(temporary, path)
        (root / (name + ".release-tmp")).unlink(missing_ok=True)
    journal.unlink()


def publish(root, changes):
    root = Path(root)
    journal = root / JOURNAL
    if journal.exists(): raise ValueError("Interrupted release: run recover before preparing again")
    if set(changes) != {"VERSION", "CHANGELOG.md", "project.godot"}:
        raise ValueError("Unexpected release metadata paths")
    for name in changes:
        if (root / name).is_symlink() or (root / (name + ".release-tmp")).exists():
            raise ValueError("Linked metadata or leftover temporary file; inspect manually")
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
        # A failed replacement may leave only our own staged temporary files.
        for name in changes: (root / (name + ".release-tmp")).unlink(missing_ok=True)
        recover(root)
        raise
    journal.unlink()
