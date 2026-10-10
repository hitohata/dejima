"""Regression tests for migration of an existing AdGuard configuration."""

import importlib.util
from pathlib import Path
import tempfile
import unittest

import yaml

spec = importlib.util.spec_from_file_location(
    "adguard_local_dns", Path(__file__).with_name("adguard-local-dns.py")
)
migration = importlib.util.module_from_spec(spec)
spec.loader.exec_module(migration)


class LocalDNSTest(unittest.TestCase):
    def test_disabled_rewrites_and_restricted_clients(self):
        # The live installation already had the wildcard, but globally disabled
        # rewrites and a DNS allowlist missing native Wi-Fi clients.
        original = {
            "users": [{"name": "admin", "password": "fixture-hash"}],
            "dns": {"allowed_clients": ["192.168.10.0/24", "192.168.50.0/24"]},
            "filtering": {
                "protection_enabled": False,
                "rewrites_enabled": False,
                "rewrites": [
                    {"domain": "nas.lan", "answer": "192.168.10.100"},
                    {"domain": "*.dejima.men", "answer": "192.168.60.1", "enabled": True},
                ],
            },
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "AdGuardHome.yaml"
            path.write_text(yaml.safe_dump(original))
            path.chmod(0o600)
            before = path.read_bytes()
            migration.configure(path)
            result = yaml.safe_load(path.read_text())
            self.assertTrue(result["filtering"]["rewrites_enabled"])
            self.assertFalse(result["filtering"]["protection_enabled"])
            self.assertEqual(result["filtering"]["rewrites"], [
                original["filtering"]["rewrites"][0],
                {"domain": "*.dejima.men", "answer": "192.168.10.1", "enabled": True},
            ])
            self.assertEqual(result["users"], original["users"])
            self.assertEqual(result["dns"]["allowed_clients"], [
                *original["dns"]["allowed_clients"], "192.168.60.0/24",
            ])
            backup = path.with_name(path.name + ".before-local-dns")
            self.assertEqual(backup.read_bytes(), before)
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            after = path.read_bytes()
            migration.configure(path)
            self.assertEqual(path.read_bytes(), after)
            self.assertEqual(backup.read_bytes(), before)

    def test_unrestricted_clients_stay_unrestricted(self):
        for dns in ({}, {"allowed_clients": []}):
            with self.subTest(dns=dns), tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "AdGuardHome.yaml"
                path.write_text(yaml.safe_dump({"dns": dns}))
                migration.configure(path)
                result = yaml.safe_load(path.read_text())
                self.assertEqual(result["dns"], dns)
                self.assertTrue(result["filtering"]["rewrites_enabled"])

    def test_enabled_wifi_wildcard_migrates_to_tailscale_routed_address(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "AdGuardHome.yaml"
            path.write_text(yaml.safe_dump({
                "filtering": {"rewrites_enabled": True, "rewrites": [
                    {"domain": "*.dejima.men", "answer": "192.168.60.1", "enabled": True},
                ]},
            }))
            migration.configure(path)
            result = yaml.safe_load(path.read_text())
            self.assertEqual(result["filtering"]["rewrites"], [
                {"domain": "*.dejima.men", "answer": "192.168.10.1", "enabled": True},
            ])


if __name__ == "__main__":
    unittest.main()
