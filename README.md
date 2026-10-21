# php-emergency-mitigations

[![CI](https://github.com/tmespro/php-emergency-mitigations/actions/workflows/ci.yml/badge.svg)](https://github.com/tmespro/php-emergency-mitigations/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-clean-brightgreen.svg)](https://www.shellcheck.net/)

Safe, reversible interim hardening for critical PHP vulnerabilities, for the hours or days between a disclosure and the moment patched PHP builds reach your servers.

> [!WARNING]
> **These scripts are not fixes.** They reduce exposure to specific attack paths while you wait for packages. Updating PHP is the only complete fix. Remove the mitigation once you have updated.

## Active advisories

| Advisory | CVEs | Severity | Fixed in | Status |
|---|---|---|---|---|
| [`2026-10-cve-2026-109618`](advisories/2026-10-cve-2026-109618/) | CVE-2026-109618, CVE-2026-109619 | Critical (CVSS v4.0 9.2), unauthenticated RCE | 8.5.12, 8.4.27, 8.3.36, 8.2.35 | **ACTIVE** |

Each advisory is an independent, opt-in module. Nothing is ever applied "just in case": you choose the advisory, review its plan, then apply it.

## Quick start

```bash
# 1. Get the code (or download the release assets and verify SHA256SUMS)
git clone https://github.com/tmespro/php-emergency-mitigations.git
cd php-emergency-mitigations

# 2. Read the script. It will run as root on your server.
less advisories/2026-10-cve-2026-109618/mitigate.sh

# 3. Dry run: detects your setup and prints the plan. Changes nothing.
sudo bash mitigate.sh 2026-10-cve-2026-109618

# 4. Apply, then check the Summary: every line must read PASS
sudo bash mitigate.sh 2026-10-cve-2026-109618 --apply

# 5. After updating PHP, remove the mitigation
sudo bash mitigate.sh 2026-10-cve-2026-109618 --revert --apply
```

Please do not pipe these scripts from the network straight into a root shell. Download, read, dry run, then apply.

## Safety design

Built to be run on servers its authors have never seen.

| Guarantee | How |
|---|---|
| **Dry run by default** | Without `--apply`, no file is written and no service is touched. |
| **Backups** | Every file it modifies is copied to `<file>.bak-<timestamp>` first. Rollback commands are printed at the end. |
| **Config tests and automatic rollback** | Each PHP-FPM and Apache change is validated with the service's own config test. A failing change is undone before anything is reloaded. |
| **Graceful reloads only** | `SIGUSR2` to the PHP-FPM master, `apachectl -k graceful`. No hard restart. |
| **Live verification** | After applying, a temporary probe (random name, removed immediately) asks the running PHP for the values it really uses. A setting that did not take effect is reported as `FAIL`, never as success. |
| **Idempotent** | Running it twice changes nothing the second time. |
| **Exact revert** | `--revert --apply` restores every configuration file byte-for-byte. This is checked in CI. |
| **Respects precedence** | PHP-FPM keeps the *first* value a pool sets. Conflicting earlier lines are commented out (and restored on revert) instead of being silently shadowed. |
| **Minimal footprint** | Bash 4.4+ and base tools (coreutils, grep, sed, awk; curl for the live check). No downloads, no package installs, no telemetry. |

### Exit codes

| Code | Meaning |
|---|---|
| `0` | Success (or dry run completed) |
| `1` | Precondition failed (not root, bash too old) |
| `2` | Usage error, unknown or retired advisory |
| `3` | Applied, but the live check found an unsafe value (see the `WARN` lines) |

## Tested environments

Every change runs end-to-end tests in real containers: dry run, apply, independent live check, idempotency, then byte-for-byte revert.

| Environment | Stack |
|---|---|
| Debian 12 | PHP-FPM (distribution) + nginx |
| Ubuntu 24.04 | Apache + mod_php |
| Rocky Linux 9 | PHP-FPM (AppStream) + Apache httpd |
| Official `php:8.4-fpm` image | PHP-FPM + nginx |

Also detected, best effort: Remi SCL (`phpXY`), cPanel EA-PHP, Plesk PHP, Amazon Linux, Fedora, the ondrej PPA, multiple PHP versions side by side. LiteSpeed (`lsphp`), FrankenPHP and php-cgi get the `php.ini` part only; see each advisory's notes.

## Repository layout

```
mitigate.sh                     entry point: lists and runs advisory modules
advisories/<id>/mitigate.sh     self-contained module, also runnable on its own
advisories/<id>/META            status (ACTIVE or RETIRED), CVEs, fixed versions
advisories/<id>/README.md       what the module changes and why, with sources
tests/run.sh                    end-to-end test harness used by CI
```

## Lifecycle

An advisory becomes `RETIRED` once patched builds are broadly available from PHP and the major distributions. A retired module **cannot be applied anymore**, but `--revert` keeps working so nobody is left with stale settings.

## Contributing

Bug reports with your dry-run output are the most useful contribution, especially for layouts outside the tested list. See [CONTRIBUTING.md](CONTRIBUTING.md). To report a security problem in these scripts, see [SECURITY.md](SECURITY.md).

## Disclaimer

Provided "as is", without warranty of any kind, under the [MIT License](LICENSE). You are responsible for what runs on your servers: test on staging first, keep backups, and follow your vendor's guidance. This project is not affiliated with the PHP project or any distribution.
