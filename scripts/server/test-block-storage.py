#!/usr/bin/env python3
"""호스트의 장치·fstab·Docker를 건드리지 않는 스크립트 분기 검사."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class StorageScriptsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.base = self.root / "capstone"
        self.data = self.base / "data"
        self.data.mkdir(parents=True)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.fstab = self.root / "fstab"
        self.fstab.write_text("# existing configuration\n")
        self.dropin = self.root / "gamerin-storage.conf"
        self.env = dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}",
                        GAMERIN_BASE_DIR=str(self.base))
        mock = self.bin / "mock"
        mock.write_text('''#!/usr/bin/env bash
case "${0##*/}" in
  realpath) printf '%s\\n' "$2" ;;
  blkid) if [[ "$2" = TYPE ]]; then echo "${MOCK_TYPE:-ext4}"; else echo abcd-1234; fi ;;
  mountpoint) [[ "${MOCK_MOUNTED:-1}" = 1 ]] ;;
  findmnt)
    if [[ "$*" = *FSTYPE* ]]; then echo "${MOCK_TYPE:-ext4}"
    elif [[ "$*" = *UUID* && "$*" != *-S* ]]; then echo abcd-1234
    elif [[ "$*" = *-S* ]]; then exit 1; fi ;;
  docker) [[ "${MOCK_DOCKER_FAIL:-0}" = 0 ]] || exit 1; printf '%s' "${MOCK_RUNNING:-}" ;;
  mount|systemctl|chown) echo "${0##*/}" >> "$MOCK_CALLS" ;;
esac
''')
        mock.chmod(0o755)
        for name in ("realpath", "blkid", "mountpoint", "findmnt", "docker", "mount", "systemctl", "chown"):
            (self.bin / name).symlink_to(mock)
        self.calls = self.root / "calls"
        self.env["MOCK_CALLS"] = str(self.calls)

    def run_script(self, name, *args, **environment):
        source = (Path(__file__).parent / name).read_text()
        # 권한과 블록 장치 검사는 별도 실서버 검증 대상이다. 테스트는 임시 경로만 쓴다.
        source = source.replace('[[ $EUID -eq 0 ]]', '[[ 0 -eq 0 ]]')
        source = source.replace('[[ -b "$DEVICE" ]]', '[[ -n "$DEVICE" ]]')
        source = source.replace('/etc/fstab', str(self.fstab))
        source = source.replace('/etc/systemd/system/docker.service.d/gamerin-storage.conf', str(self.dropin))
        return subprocess.run(["bash", "-c", source, name, *args],
                              env=dict(self.env, **environment), text=True, capture_output=True)

    def test_init_success_and_repeat(self):
        for _ in range(2):
            result = self.run_script("init-server-dirs-block-storage.sh")
            self.assertEqual(result.returncode, 0, result.stderr)
        for name in ("postgres", "uploads", "tmp"):
            self.assertTrue((self.data / name).is_dir())

    def test_init_rejects_missing_mount_wrong_type_and_running_containers(self):
        for environment in ({"MOCK_MOUNTED": "0"}, {"MOCK_TYPE": "xfs"},
                            {"MOCK_RUNNING": "container"}, {"MOCK_DOCKER_FAIL": "1"}):
            result = self.run_script("init-server-dirs-block-storage.sh", **environment)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((self.data / "postgres").exists())

    def test_mount_registers_once_and_preserves_existing_files(self):
        old = self.data / "existing-data"
        old.write_text("keep")
        for _ in range(2):
            result = self.run_script("mount-block-storage.sh", "/dev/mock", str(self.data))
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.fstab.read_text().count("UUID=abcd-1234"), 1)
        self.assertIn(f"RequiresMountsFor={self.data}", self.dropin.read_text())
        self.assertEqual(old.read_text(), "keep")

    def test_mount_rejects_conflict_before_writing(self):
        self.fstab.write_text(f"UUID=other {self.data} ext4 defaults 0 2\n")
        result = self.run_script("mount-block-storage.sh", "/dev/mock", str(self.data))
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.dropin.exists())

    def test_mount_executes_for_unmounted_device(self):
        result = self.run_script("mount-block-storage.sh", "/dev/mock", str(self.data), MOCK_MOUNTED="0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("mount\n", self.calls.read_text())

    def test_mount_rejects_running_containers_and_wrong_format(self):
        for environment in ({"MOCK_MOUNTED": "0", "MOCK_RUNNING": "container"},
                            {"MOCK_TYPE": "xfs"}, {"MOCK_MOUNTED": "0", "MOCK_DOCKER_FAIL": "1"}):
            result = self.run_script("mount-block-storage.sh", "/dev/mock", str(self.data), **environment)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(self.fstab.read_text(), "# existing configuration\n")


if __name__ == "__main__":
    unittest.main()
