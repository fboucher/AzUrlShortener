How It Works
============

This page as been moved to the [wiki: How-It-Works](https://github.com/microsoft/AzUrlShortener/wiki/How-It-Works)
## Non-vanity short codes

When no vanity is provided, the short code is purely random (no sequential prefix), picked from a 64-character alphabet. Its length (4–32) can be changed in the admin tool under **Settings** > **Non Vanity Code Length**, and applies to the next URL created. Until a value is saved there, the `NonVanityCodeLength` environment variable/app setting is used, or 7 if it is not set.
