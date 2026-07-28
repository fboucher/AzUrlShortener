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
