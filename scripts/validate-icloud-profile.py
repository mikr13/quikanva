#!/usr/bin/env python3
"""Validate decoded Apple provisioning metadata; print only the profile UUID."""
import datetime
import plistlib
import sys
import uuid


def validate(profile, required):
    entitlements = profile.get("Entitlements", {})
    if "NDLJGT2AYB" not in profile.get("TeamIdentifier", []):
        raise ValueError("The iCloud provisioning profile belongs to a different team.")
    app_id = entitlements.get("com.apple.application-identifier", entitlements.get("application-identifier"))
    if app_id != "NDLJGT2AYB.com.mihirpandey.quikanva":
        raise ValueError("The profile must authorize Quikanva's explicit App ID.")
    expiration = profile.get("ExpirationDate")
    if expiration is None or expiration.replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc):
        raise ValueError("The iCloud provisioning profile has expired.")
    for key, value in required.items():
        allowed = entitlements.get(key)
        # Apple may authorize all iCloud services with a scalar wildcard.
        # Container identifiers, environment, and App ID remain checked separately.
        if key == "com.apple.developer.icloud-services" and allowed == "*":
            continue
        if isinstance(value, list):
            if not isinstance(allowed, list) or not set(value).issubset(allowed):
                raise ValueError(f"The profile does not authorize {key}.")
        elif not (value in allowed if isinstance(allowed, list) else allowed == value):
            raise ValueError(f"The profile does not authorize {key}={value}.")
    identifier = profile.get("UUID")
    if not identifier:
        raise ValueError("The profile has no UUID.")
    uuid.UUID(identifier)
    return identifier


if __name__ == "__main__":
    try:
        with open(sys.argv[1], "rb") as source:
            profile = plistlib.load(source)
        with open(sys.argv[2], "rb") as source:
            required = plistlib.load(source)
        print(validate(profile, required))
    except (ValueError, OSError, IndexError, plistlib.InvalidFileException) as error:
        sys.exit(str(error))
