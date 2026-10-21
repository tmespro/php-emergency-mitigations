# Contributing

Thank you for helping keep PHP servers safe while patches roll out.

## Reporting a layout problem

The most valuable contribution is a report from an environment we do not test. Open an issue with:

- distribution and version, and how PHP was installed (distribution packages, Remi, ondrej PPA, cPanel, Plesk, Docker image, source build)
- web server and how it talks to PHP (PHP-FPM, mod_php, LiteSpeed, FrankenPHP)
- the full **dry-run** output (`sudo bash mitigate.sh <advisory-id>`), with anything sensitive removed

## Code standards

Every module must:

- run on bash 4.4+ with base tools only (coreutils, grep, sed, awk, curl): no downloads, no package installs
- default to a dry run; write nothing without `--apply`
- back up every file it modifies, and support an exact `--revert`
- validate every change with the service's own config test, and undo it on failure
- reload gracefully, never hard-restart
- verify the live result and report `FAIL` honestly
- be idempotent
- pass `shellcheck -S style` with no findings
- pass `tests/run.sh` on every CI target

Keep the scope to what the official advisory recommends. A mitigation module is not the place for general hardening.

## Running the tests

The end-to-end harness installs a real PHP stack inside a throwaway container. Never run it on a real server.

```bash
docker run --rm -v "$PWD:/repo:ro" -w /repo debian:12 bash tests/run.sh debian-nginx-fpm
docker run --rm -v "$PWD:/repo:ro" -w /repo ubuntu:24.04 bash tests/run.sh ubuntu-apache-modphp
docker run --rm -v "$PWD:/repo:ro" -w /repo rockylinux:9 bash tests/run.sh rocky-httpd-fpm
docker run --rm -v "$PWD:/repo:ro" -w /repo php:8.4-fpm-bookworm bash tests/run.sh official-fpm-nginx
```

## Adding an advisory

1. Create `advisories/<YYYY-MM>-<primary-cve-lowercase>/` with `mitigate.sh`, `META` and `README.md`. Use the existing advisory as the template.
2. Map every change in the module to a recommendation in the official advisory, in the advisory README.
3. Add the advisory to the table in the main README and to `CHANGELOG.md`.
4. Add or adapt CI targets so the new module is tested end to end.

## Retiring an advisory

When patched builds are broadly available, set `status=RETIRED` in its `META`, update the README tables, and note it in `CHANGELOG.md`. Do not delete the module: people still need `--revert`.
