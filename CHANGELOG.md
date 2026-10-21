# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and module versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-10-21

### Added

- Entry point `mitigate.sh` with `list`, advisory dispatch and RETIRED-advisory protection.
- Advisory `2026-10-cve-2026-109618` for CVE-2026-109618 and CVE-2026-109619 (critical unauthenticated RCE in PHP):
  - PHP-FPM pool hardening that respects PHP-FPM's first-value-wins precedence
  - php.ini snippets in every detected conf.d directory
  - Apache request limits, and `php_admin_*` values for mod_php
  - nginx audit
  - config tests with automatic rollback, graceful reloads, live verification, exact revert
- End-to-end CI on Debian 12, Ubuntu 24.04, Rocky Linux 9 and the official `php:8.4-fpm` image.

[1.0.0]: https://github.com/tmespro/php-emergency-mitigations/releases/tag/v1.0.0
