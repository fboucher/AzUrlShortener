# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased] - By Michael Morten Sonne

### Added

- Added Entra role-based authorization for API and admin flows
- Added RBAC-focused validation tooling for Entra app-role assignments and managed identity wiring.
- Added a new setup helper script: src/tools/setup-admin-auth.ps1.
- Added WhatIf support to src/tools/setup-admin-auth.ps1 for safe preview of changes.
- Added script documentation file: src/tools/README.md.
- Added script documentation file: src/tools/setup-admin-auth.md.
- Added script documentation file: src/tools/validate-setup.md.
- Added script documentation file: src/tools/validate-setup-sonnes.md.

### Changed

- Improved FAQ structure in doc/faq.md with grouped quick links.
- Added script usage and WhatIf examples in doc/faq.md.
- Added scripts documentation links in README.md.
- Fixed managed identity authentication path for downstream API calls used by admin.

## [v4.1.1] - 2025-05-26

### Release

- [Release v4.1.1: Update packages and upgrade to .NET Aspire 9.3 (#573) · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/v4.1.1)
- [v4.1.1: Update packages and upgrade to .NET Aspire 9.3 (#573)](https://github.com/fboucher/AzUrlShortener/releases/tag/v4.1.1)
- Tagged by [fboucher](https://github.com/fboucher) on May 26, 2025 (commit 532f09d)

### Notes

- Enhances data migration documentation and updates dependencies (#572).
- Adds a Discord badge.
- Updates dependencies to latest versions.
- Fixes anchors in the help page.
- Adds documentation for data migration.

## [v4.1] - 2025-04-27

### Release

- [Release v4.1: Version 4.1 (#569) · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/v4.1)
- [v4.1: Version 4.1 (#569)](https://github.com/fboucher/AzUrlShortener/releases/tag/v4.1)
- Tagged by [fboucher](https://github.com/fboucher) on April 27, 2025 (commit 133288f)

### Notes

- Updates packages.
- Adds CSV import flow for URL and click stats (#554).
- Adds URL manager filtering for vanity URL and title (#565).
- Adds CreatedDate to ShortUrlEntity (#567).
- Adds archived URL checks before redirect (#561).
- Improves build workflow and Help/Home documentation text.

## [v4.0.1] - 2025-03-26

### Release

- [Release v4.0.1: Hotfix v4 0 1 (#557) · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/v4.0.1)
- [v4.0.1: Hotfix v4 0 1 (#557)](https://github.com/fboucher/AzUrlShortener/releases/tag/v4.0.1)
- Tagged by [fboucher](https://github.com/fboucher) on March 26, 2025 (commit 37f230c)

### Notes

- Updates package references to latest versions.
- Removes unused Azure configuration files and templates.
- Removes unused media and updates README image paths.
- Shortens project paths.
- Cleans up code structure and using directives.
- Fixes issue #532.
- Updates TinyBlazorAdmin documentation pages.
- Adds handling for no-stats error.

## [v4.0] - 2025-03-20

### Release

- [Release v4.0: This is version 4 (#549) · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/v4.0)
- [v4.0: This is version 4 (#549)](https://github.com/fboucher/AzUrlShortener/releases/tag/v4.0)
- Tagged by [fboucher](https://github.com/fboucher) on March 20, 2025 (commit 7a1d28b)

### Notes

- Moves to .NET Aspire solution architecture.
- Moves deployment to Azure Container Apps and Azure Developer CLI.
- Replaces Syncfusion components with Blazor Bootstrap and updates charts.
- Updates GitHub Actions workflow and branch handling.
- Adds FAQ documentation and refreshes README/images.

## [v3.0] - 2022-11-25

### Release

- [Release v3.0: Delete main_testgithubdepbglxc.yml · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/v3.0)
- [v3.0: Delete main_testgithubdepbglxc.yml](https://github.com/fboucher/AzUrlShortener/releases/tag/v3.0)
- Tagged by [fboucher](https://github.com/fboucher) on November 25, 2022 (commit 2d0180f)

### Notes

- Deletes obsolete workflow file main_testgithubdepbglxc.yml.

## [v2.1.0] - 2021-02-03

### Release

- [Release v2.1.0: Deleting ghost code · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/v2.1.0)
- [v2.1.0: Deleting ghost code](https://github.com/fboucher/AzUrlShortener/releases/tag/v2.1.0)
- Tagged by [fboucher](https://github.com/fboucher) on February 3, 2021 (commit 726d8d7)

### Notes

- Deletes ghost code.

## [2.0.2] - 2020-12-29

### Release

- [Release 2.0.2: New Release Version 2.0.2 · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/2.0.2)
- [2.0.2: New Release Version 2.0.2](https://github.com/fboucher/AzUrlShortener/releases/tag/2.0.2)
- Tagged by [fboucher](https://github.com/fboucher) on December 29, 2020 (commit 634c80d)

### Notes

- New release version 2.0.2.

## [2.0.1] - 2020-12-06

### Release

- [Release 2.0.1: Fixing the mapping of the custom domain · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/2.0.1)
- [2.0.1: Fixing the mapping of the custom domain](https://github.com/fboucher/AzUrlShortener/releases/tag/2.0.1)
- Tagged by [fboucher](https://github.com/fboucher) on December 6, 2020 (commit ec9dafb)

### Notes

- Fixes custom-domain mapping.

## [2.0] - 2020-11-05

### Release

- [Release 2.0: Major upgrade to version 2.0 · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/2.0)
- [2.0: Major upgrade to version 2.0](https://github.com/fboucher/AzUrlShortener/releases/tag/2.0)
- Tagged by [fboucher](https://github.com/fboucher) on November 5, 2020 (commit 6c3269a)

### Notes

- Major upgrade to version 2.0.

## [v1.0] - 2020-07-23

### Release

- [Release v1.0: Merge remote-tracking branch 'origin/main' into main · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/v1.0)
- [v1.0: Merge remote-tracking branch 'origin/main' into main](https://github.com/fboucher/AzUrlShortener/releases/tag/v1.0)
- Tagged by [fboucher](https://github.com/fboucher) on July 23, 2020 (commit 82644e1)

### Notes

- Merge remote-tracking branch origin/main into main.

## [v0.6.1] - 2020-07-23

### Release

- [Release v0.6.1: Merge branch 'main' into vnext · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/v0.6.1)
- [v0.6.1: Merge branch 'main' into vnext](https://github.com/fboucher/AzUrlShortener/releases/tag/v0.6.1)
- Tagged by [fboucher](https://github.com/fboucher) on July 23, 2020 (commit c189ffc)

### Notes

- Merges main into vnext.

## [v0.6] - 2020-06-21

### Release

- [Release v0.6: docs: add Hedlund01 as a contributor · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/v0.6)
- [v0.6: docs: add Hedlund01 as a contributor](https://github.com/fboucher/AzUrlShortener/releases/tag/v0.6)
- Tagged by [fboucher](https://github.com/fboucher) on June 21, 2020 (commit 6476059)

### Notes

- Adds Hedlund01 as a contributor.

## [v0.5] - 2020-05-29

### Release

- [Release v0.5: Update to version 0.5 · fboucher/AzUrlShortener](https://github.com/fboucher/AzUrlShortener/releases/tag/v0.5)
- [v0.5: Update to version 0.5](https://github.com/fboucher/AzUrlShortener/releases/tag/v0.5)
- Tagged by [fboucher](https://github.com/fboucher) on May 29, 2020 (commit 0629cc9)

### Notes

- Update to version 0.5.
