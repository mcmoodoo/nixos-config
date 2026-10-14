"""Exercise deployment safeguards with temporary files and fake commands only.

Never runs main(), sudo, nixos-rebuild, activation, or a real compositor.
Run: python3 -m unittest discover -s tests -p 'test_deploy_script.py' -v
"""
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/deploy-thinkbook16-g7.sh"


class DeploySafetyTests(unittest.TestCase):
    def setUp(self):
        scratch = SCRIPT.parents[1] / ".validation"
        scratch.mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="deploy-test-", dir=scratch)
        self.root = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)

    def run_helper(self, body, *args, success=True):
        env = os.environ.copy()
        env["THINKBOOK_TEST_ROOT"] = str(self.root)
        result = subprocess.run(
            ["bash", "-c", f"source {shlex.quote(str(SCRIPT))}\n{body}", "test", *map(str, args)],
            text=True, capture_output=True, env=env,
        )
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_target_identity_and_refusal_cases(self):
        valid = ["reed", "/home/reed", "x86_64", "26.05.123", "GenuineIntel Intel Core Ultra 5 125U",
                 "LENOVO\n21MS\nThinkBook 16 G7 IML", "yes"]
        self.run_helper('validate_identity "$@"', *valid)
        for index, value in [(0, "root"), (0, "mcmoodoo"), (1, "/root"), (2, "aarch64"),
                             (3, "25.11"), (4, "AuthenticAMD Ryzen 8845H"),
                             (4, "GenuineIntel Core i7"), (5, "LENOVO ThinkBook 14 G6+ AHP"), (6, "no")]:
            with self.subTest(index=index, value=value):
                invalid = valid.copy()
                invalid[index] = value
                self.run_helper('validate_identity "$@"', *invalid, success=False)

    def test_hardware_import_is_repeatable_without_overwriting(self):
        source, destination = self.root / "generated.nix", self.root / "hardware.nix"
        source.write_text('{ fileSystems."/".device = "/dev/disk/by-uuid/local"; }\n')
        self.run_helper('import_hardware "$1" "$2"', source, destination)
        self.assertEqual(destination.read_bytes(), source.read_bytes())
        previous_mtime = destination.stat().st_mtime_ns
        self.run_helper('import_hardware "$1" "$2"', source, destination)
        self.assertEqual(destination.stat().st_mtime_ns, previous_mtime)
        destination.write_text("existing local work\n")
        self.run_helper('import_hardware "$1" "$2"', source, destination, success=False)
        self.assertEqual(destination.read_text(), "existing local work\n")
        self.assertIn("local", source.read_text())

    def test_hardware_import_rejects_symlinks_and_missing_source(self):
        source, destination = self.root / "source.nix", self.root / "destination.nix"
        source.write_text("preserve me\n")
        destination.symlink_to(source)
        self.run_helper('import_hardware "$1" "$2"', source, destination, success=False)
        self.assertEqual(source.read_text(), "preserve me\n")
        self.run_helper('import_hardware "$1" "$2"', self.root / "absent", destination, success=False)

    def inspection_fixture(self):
        root_device, boot_device = self.root / "root-device", self.root / "efi-device"
        root_device.touch()
        boot_device.touch()
        root_link = self.root / "root-by-uuid"
        root_link.symlink_to(root_device)
        data = {
            "stateVersion": "26.05", "hostname": "thinkbook16-g7",
            "root": {"fsType": "ext4", "device": str(root_link)},
            "efi": {"fsType": "vfat", "device": str(boot_device), "options": ["umask=0077"]},
            "luks": [], "swap": [], "resumeDevice": "",
            "user": {"home": "/home/reed", "extraGroups": ["wheel", "networkmanager", "docker"]},
            "mutableUsers": True, "intelMicrocode": True,
        }
        return data, root_device, boot_device

    def test_inspection_accepts_resolved_local_devices(self):
        data, root_device, boot_device = self.inspection_fixture()
        report = self.root / "inspection.json"
        report.write_text(json.dumps(data))
        self.run_helper('validate_inspection "$1" "$2" "$3"', report, root_device, boot_device)

    def test_inspection_rejects_wrong_devices_and_policy(self):
        data, root_device, boot_device = self.inspection_fixture()
        report = self.root / "inspection.json"
        report.write_text(json.dumps(data))
        self.run_helper('validate_inspection "$1" "$2" "$3"', report, boot_device, root_device, success=False)
        changes = [
            ("stateVersion", "25.05"), ("luks", ["cryptroot"]), ("swap", [{"device": "/swapfile"}]),
            ("resumeDevice", "/dev/old"), ("mutableUsers", False), ("intelMicrocode", False),
            ("user", {"home": "/home/mcmoodoo", "extraGroups": ["wheel", "networkmanager"]}),
            ("user", {"home": "/home/reed", "extraGroups": ["networkmanager"]}),
            ("efi", {**data["efi"], "options": ["fmask=0022", "dmask=0022"]}),
            ("root", {**data["root"], "fsType": "btrfs"}),
        ]
        for key, value in changes:
            with self.subTest(key=key, value=value):
                report.write_text(json.dumps({**data, key: value}))
                self.run_helper('validate_inspection "$1" "$2" "$3"', report, root_device, boot_device, success=False)

    def test_backups_and_gc_roots_preserve_the_first_generation(self):
        config = self.root / "nixos"
        config.mkdir()
        for name in ["configuration.nix", "hardware-configuration.nix"]:
            (config / name).write_text("minimal installation\n")
        generations = []
        for name in ["minimal", "later"]:
            generation = self.root / name
            (generation / "bin").mkdir(parents=True)
            activation = generation / "bin/switch-to-configuration"
            activation.write_text("#!/bin/sh\nexit 99\n")
            activation.chmod(0o755)
            generations.append(generation)
        # This sudo replacement only executes whitelisted file operations inside
        # this test's temporary directory. It cannot escalate or touch the host.
        body = '''
sudo() {
    case "$1" in install|mktemp|cp|ln|test) ;; *) exit 98 ;; esac
    for argument in "$@"; do
        case "$argument" in
            "$THINKBOOK_TEST_ROOT"/*) ;;
            /*) exit 97 ;;
        esac
    done
    "$@"
}
backup_installation "$1" "$2" "$3" "$4"
'''
        backups, roots = self.root / "backups", self.root / "gcroots"
        for generation in generations:
            self.run_helper(body, config, generation, backups, roots)
        self.assertEqual((roots / "minimal-system").resolve(), generations[0])
        retained = list(roots.glob("pre-deploy-*"))
        self.assertEqual({p.resolve() for p in retained}, set(generations))
        snapshots = list(backups.glob("pre-deploy-*/nixos/configuration.nix"))
        self.assertEqual(len(snapshots), 2)
        for snapshot in snapshots:
            self.assertEqual(snapshot.read_bytes(), (config / "configuration.nix").read_bytes())
        self.assertEqual(backups.stat().st_mode & 0o777, 0o700)
        (roots / "minimal-system").unlink()
        (roots / "minimal-system").write_text("do not overwrite")
        self.run_helper(body, config, generations[1], backups, roots, success=False)
        self.assertEqual((roots / "minimal-system").read_text(), "do not overwrite")

    def test_compositor_error_with_zero_exit_stops_before_installation(self):
        system = self.root / "system"
        (system / "sw/bin").mkdir(parents=True)
        checker = system / "sw/bin/Hyprland"
        checker.write_text("#!/bin/sh\nprintf 'Config error: invalid dispatcher\\n'\nexit 0\n")
        checker.chmod(0o755)
        config = self.root / "hyprland.conf"
        config.write_text("test only\n")
        marker = self.root / "must-not-install"
        body = 'verify_desktop "$1" "$2" "$3"\ntouch "$4"'
        self.run_helper(body, system, config, self.root / "logs", marker, success=False)
        self.assertFalse(marker.exists())
        checker.write_text("#!/bin/sh\nprintf 'config ok\\n'\n")
        self.run_helper(body, system, config, self.root / "logs", marker)
        self.assertTrue(marker.exists())


if __name__ == "__main__":
    unittest.main()
