import datetime
import importlib.util
from pathlib import Path
import plistlib
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("profile_validator", ROOT / "scripts/validate-icloud-profile.py")
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class ProfileTests(unittest.TestCase):
    def setUp(self):
        with (ROOT / "config/CloudKit-Release.entitlements").open("rb") as source:
            self.required = plistlib.load(source)
        self.profile = {
            "UUID": "11111111-2222-3333-4444-555555555555",
            "TeamIdentifier": ["NDLJGT2AYB"],
            "ExpirationDate": datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=365),
            "Entitlements": dict(self.required, **{
                "com.apple.application-identifier": "NDLJGT2AYB.com.mihirpandey.quikanva"
            }),
        }

    def test_matching_profile_is_accepted(self):
        self.assertEqual(validator.validate(self.profile, self.required), self.profile["UUID"])

    def test_apple_icloud_service_wildcard_is_accepted_with_explicit_container(self):
        self.profile["Entitlements"]["com.apple.developer.icloud-services"] = "*"
        self.assertEqual(validator.validate(self.profile, self.required), self.profile["UUID"])
        self.profile["Entitlements"]["com.apple.developer.icloud-container-identifiers"] = ["iCloud.other.app"]
        with self.assertRaises(ValueError):
            validator.validate(self.profile, self.required)

    def test_wrong_team_or_application_is_rejected(self):
        self.profile["TeamIdentifier"] = ["OTHERTEAM"]
        with self.assertRaises(ValueError):
            validator.validate(self.profile, self.required)
        self.profile["TeamIdentifier"] = ["NDLJGT2AYB"]
        self.profile["Entitlements"]["com.apple.application-identifier"] = "NDLJGT2AYB.*"
        with self.assertRaises(ValueError):
            validator.validate(self.profile, self.required)

    def test_missing_cloudkit_and_push_permissions_are_rejected(self):
        for key in self.required:
            with self.subTest(key=key):
                original = self.profile["Entitlements"].pop(key)
                with self.assertRaises(ValueError):
                    validator.validate(self.profile, self.required)
                self.profile["Entitlements"][key] = original

    def test_development_profile_cannot_ship_as_production(self):
        self.profile["Entitlements"]["com.apple.developer.icloud-container-environment"] = "Development"
        with self.assertRaises(ValueError):
            validator.validate(self.profile, self.required)

    def test_profile_can_authorize_multiple_container_environments(self):
        self.profile["Entitlements"]["com.apple.developer.icloud-container-environment"] = ["Development", "Production"]
        self.assertEqual(validator.validate(self.profile, self.required), self.profile["UUID"])

    def test_malformed_uuid_is_rejected(self):
        self.profile["UUID"] = "invalid"
        with self.assertRaises(ValueError):
            validator.validate(self.profile, self.required)

    def test_expired_profile_is_rejected(self):
        self.profile["ExpirationDate"] = datetime.datetime(2020, 1, 1)
        with self.assertRaises(ValueError):
            validator.validate(self.profile, self.required)


if __name__ == "__main__":
    unittest.main()
