#!/usr/bin/env python3
"""Local verification evidence; never a substitute for Cloud or product acceptance."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def git(*args):
    return subprocess.check_output(['git', '-C', str(root), *args])


def fingerprint():
    names = set(git('ls-files', '-z', '--cached', '--others', '--exclude-standard').split(b'\0')) - {b''}
    paths = {root / os.fsdecode(name) for name in names}
    # Installed executors and local configuration may intentionally be ignored.
    runtime = Path(__file__).resolve().parent.parent
    for directory in (runtime / 'scripts', runtime / 'backend'):
        paths.update(p for p in directory.rglob('*') if p.is_file() or p.is_symlink())
    for path in [root / 'runtime.local.yml', *[runtime / name for name in ('runtime.yml', 'runtime.local.yml', '.swiftlint.yml', '.swiftformat', 'Brewfile', '.runtime-lock', 'justfile')]]:
        if path.exists():
            paths.add(path)
    digest = hashlib.sha256()
    for path in sorted(paths, key=str):
        label = str(path.relative_to(root)) if path.is_relative_to(root) else str(path)
        if path.is_symlink():
            data = b'link\0' + os.fsencode(os.readlink(path))
        elif path.is_file():
            data = (b'executable\0' if path.stat().st_mode & 0o111 else b'file\0') + path.read_bytes()
        elif not path.exists():
            continue
        else:
            raise ValueError('Directory/submodule input is unsupported: ' + label)
        digest.update(os.fsencode(label) + b'\0')
        digest.update(hashlib.sha256(data).digest())
    return digest.hexdigest()


def main():
    mode = sys.argv[1]
    receipt = Path(os.fsdecode(git('rev-parse', '--git-path', 'runtime-verify.json')).strip())
    if not receipt.is_absolute():
        receipt = root / receipt
    if mode == 'invalidate':
        receipt.unlink(missing_ok=True)
    elif mode == 'fingerprint':
        print(fingerprint())
    elif mode == 'record':
        current = fingerprint()
        if current != sys.argv[2]:
            raise ValueError('Inputs changed during verify; run verify again.')
        payload = {'schema': 1, 'fingerprint': current}
        with tempfile.NamedTemporaryFile(mode='w', dir=receipt.parent, delete=False) as out:
            json.dump(payload, out)
            temporary = out.name
        os.replace(temporary, receipt)
    elif mode == 'check':
        if not receipt.exists():
            raise ValueError('No successful verification evidence; run just verify.')
        payload = json.loads(receipt.read_text())
        if payload.get('schema') != 1 or payload.get('fingerprint') != fingerprint():
            raise ValueError('Verification is stale; run just verify for the current contents.')
        if git('status', '--porcelain', '--untracked-files=all').strip():
            raise ValueError('Commit the verified contents before release; working tree is not clean.')
        print('Release preflight OK: verified contents match HEAD ' + git('rev-parse', 'HEAD').decode().strip())
    else:
        raise ValueError('Unknown verification-state command: ' + mode)


if __name__ == '__main__':
    try:
        root = Path(subprocess.check_output(['git', '-C', os.environ.get('PROJECT_ROOT', os.getcwd()), 'rev-parse', '--show-toplevel']).decode().strip())
        main()
    except (ValueError, OSError, subprocess.CalledProcessError, IndexError) as error:
        print('Verification evidence: ' + str(error), file=sys.stderr)
        sys.exit(1)
