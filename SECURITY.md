# Security policy

## Reporting a problem in these scripts

These scripts run as root on production servers, so we treat their bugs as security issues.

If you find a way a script could weaken a server, corrupt a configuration, leak information, or report `PASS` for a setting that is not actually in effect, please report it **privately**:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability** (GitHub private vulnerability reporting).

Please include your distribution, how PHP was installed, your web server, and the script output. Remove hostnames, paths or values you consider sensitive.

We aim to acknowledge reports within 48 hours. Fixes for an ACTIVE advisory are released as quickly as possible, because the window in which these scripts are useful is short.

## Not in scope

- **Vulnerabilities in PHP itself.** Report them to the PHP security team through the [php-src security advisories](https://github.com/php/php-src/security), not here.
- Questions about whether a server is affected: check the official advisory and your vendor's announcements.

## Supported versions

Only the latest release of each ACTIVE advisory is supported. RETIRED advisories only receive fixes to `--revert`.
