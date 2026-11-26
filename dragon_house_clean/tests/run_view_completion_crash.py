"""Isolated process-kill integration test; never uses the owner's user://."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile
import time

def run(engine, project, backend, backup):
    mode = "verify_backup" if backup else "verify_primary"
    with tempfile.TemporaryDirectory(prefix="dragon-crash-") as temp:
        data = Path(temp)
        # Godot Linux user:// resolves under XDG_DATA_HOME. Reject running on
        # another platform rather than risk touching the owner's world.
        if os.name != "posix" or not Path("/proc").exists():
            raise RuntimeError("Linux QA only")
        env = dict(os.environ, XDG_DATA_HOME=temp,
                   DRAGON_OBJECT_EVENT_BACKEND=backend,
                   DRAGON_QA_CRASH_MODE="write")
        cmd = [engine, "--headless", "--path", str(project),
               "--script", "tests/test_view_completion_crash.gd"]
        with (data / "worker.log").open("w+") as log:
            proc = subprocess.Popen(cmd, env=env, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 40
                while time.monotonic() < deadline:
                    if "CRASH_FIXTURE_READY" in (data / "worker.log").read_text():
                        break
                    if proc.poll() is not None:
                        raise RuntimeError((data / "worker.log").read_text())
                    time.sleep(0.05)
                else:
                    raise RuntimeError((data / "worker.log").read_text())
                proc.kill()
                proc.wait(timeout=10)
                assert proc.returncode == -9
            finally:
                if proc.poll() is None:
                    proc.kill()
                    proc.wait(timeout=10)
        print((data / "worker.log").read_text().strip())
        files = list(data.rglob("view_completion_crash.json"))
        assert len(files) == 1, files
        if backup:
            files[0].write_text("{simulated torn primary")
        env["DRAGON_QA_CRASH_MODE"] = mode
        result = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=40)
        print(result.stdout, result.stderr, sep="")
        assert result.returncode == 0 and "CRASH_RECOVERY_PASS" in result.stdout
        assert "SCRIPT ERROR" not in result.stderr

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", default=".")
    parser.add_argument("--backend", choices=["json", "sqlite"], required=True)
    args = parser.parse_args()
    for backup in (False, True):
        run(args.godot, Path(args.project).resolve(), args.backend, backup)
