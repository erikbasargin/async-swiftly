#!/usr/bin/env python3
##===----------------------------------------------------------------------===##
##
## This source file is part of the async-swiftly open source project
##
## Copyright (c) 2026 Erik Basargin and the async-swiftly project authors
## SPDX-License-Identifier: MIT
##
## See LICENSE for license information
##
##===----------------------------------------------------------------------===##

import fcntl
import json
import os
import re
import shlex
import signal
import subprocess
import sys
import tempfile
from pathlib import Path


def interrupted(signum, frame):
    raise SystemExit(128 + signum)


signal.signal(signal.SIGTERM, interrupted)
swift = subprocess.check_output(["swiftly", "run", "which", "swift"], text=True).strip()
if not Path(swift).is_absolute() or Path(swift).name != "swift":
    raise SystemExit("Swiftly did not resolve an absolute Swift compiler path")

# Muter 16 clears its child processes' environment, including the PATH needed
# to find the linker. The temporary launcher must be named 'swift' so Muter
# still recognizes SwiftPM and enables its coverage/build handling.
with tempfile.TemporaryDirectory(prefix="muter-swift-") as directory, open(
    "muter.conf.yml", "r+b"
) as config:
    launcher = Path(directory) / "swift"
    tool_path = os.pathsep.join([
        str(Path(swift).parent),
        os.environ.get("PATH", os.defpath)
    ])
    launcher.write_text(
        "#!/bin/sh\n"
        f"export PATH={shlex.quote(tool_path)}\n"
        f'exec {shlex.quote(swift)} "$@"\n'
    )
    launcher.chmod(0o700)

    # Hold a lock so simultaneous task runs cannot overwrite each other's config.
    try:
        fcntl.flock(config, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit("Another Muter task is already using muter.conf.yml")
    original = config.read()
    updated, count = re.subn(
        r"^executable:.*$",
        lambda _: "executable: " + json.dumps(str(launcher)),
        original.decode(),
        flags=re.MULTILINE,
    )
    if count != 1:
        raise SystemExit("Expected one executable entry in muter.conf.yml")
    try:
        config.seek(0)
        config.write(updated.encode())
        config.truncate()
        config.flush()
        result = subprocess.run(["muter", "run", "--skip-update-check", *sys.argv[1:]])
    finally:
        config.seek(0)
        config.write(original)
        config.truncate()
        config.flush()

sys.exit(result.returncode if result.returncode >= 0 else 128 - result.returncode)
