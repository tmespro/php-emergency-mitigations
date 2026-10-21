#!/usr/bin/env bash
# =============================================================================
# End-to-end test for an advisory module, run as root inside a throwaway
# container (see .github/workflows/ci.yml). It installs a real PHP stack,
# plants a realistic trap (a finite memory_limit set early in the pool), then:
#
#   1. dry run     must succeed and change no file
#   2. --apply     must report PASS and the live values must be safe
#   3. --apply     again must change nothing (idempotent)
#   4. --revert    must restore every config file byte-for-byte
#                  and the live values must be back to the original ones
#
# Usage:   bash tests/run.sh <target> [advisory-id]
# Targets: debian-nginx-fpm | ubuntu-apache-modphp | rocky-httpd-fpm | official-fpm-nginx
# Set SKIP_SETUP=1 to test against services that are already installed and running.
# =============================================================================
set -Eeuo pipefail

TARGET="${1:?usage: tests/run.sh <target> [advisory-id]}"
ADVISORY="${2:-2026-10-cve-2026-109618}"
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d)
DOCROOT=/var/www/html
POOL=""
FAILS=0

log()  { printf '\n\033[1m### %s\033[0m\n' "$*"; }
ok()   { printf '  ok   %s\n' "$*"; }
bad()  { printf '  FAIL %s\n' "$*"; FAILS=$((FAILS + 1)); }

run_mod() {   # runs the module through the entry point, keeps output and exit code
  local out="$1"; shift
  set +e
  bash "$REPO/mitigate.sh" "$ADVISORY" --force "$@" > "$out" 2>&1
  local rc=$?
  set -e
  echo "$rc"
}

snapshot() {  # checksums of every config file, ignoring our own backups
  local d
  for d in /etc/php /etc/php.d /etc/php-fpm.d /etc/php-fpm.conf /etc/httpd /etc/apache2 /etc/nginx /usr/local/etc; do
    if [[ -e "$d" ]]; then find "$d" \( -type f -o -type l \) ! -name '*.bak-*' -exec sha256sum {} + 2>/dev/null || true; fi
  done | sort
}

live() {      # values PHP really uses for web requests
  local f="$DOCROOT/live-$RANDOM.php"
  echo '<?php echo ini_get("memory_limit"), "|", ini_get("session.upload_progress.enabled") ?: "0", "|", PHP_SAPI;' > "$f"
  chmod 644 "$f"
  curl -s --max-time 10 "http://127.0.0.1/$(basename "$f")" || true
  rm -f "$f"
}

# ------------------------------------------------------------------ setup ---
setup_debian_nginx_fpm() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends php-fpm nginx curl procps >/dev/null
  local v; v=$(ls /etc/php)
  POOL="/etc/php/$v/fpm/pool.d/www.conf"
  cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    root $DOCROOT;
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php$v-fpm.sock;
    }
}
EOF
  plant_trap
  mkdir -p /run/php "$DOCROOT"
  "/usr/sbin/php-fpm$v" --daemonize
  nginx
}

setup_ubuntu_apache_modphp() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends apache2 libapache2-mod-php curl procps >/dev/null
  a2dismod -q mpm_event >/dev/null 2>&1 || true
  a2enmod -q mpm_prefork >/dev/null
  a2enmod -q "php$(ls /etc/php)" >/dev/null
  echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
  a2enconf -q servername >/dev/null
  # mod_php trap: a finite memory_limit in the server config
  echo "php_admin_value memory_limit 256M" > /etc/apache2/conf-available/app-limits.conf
  a2enconf -q app-limits >/dev/null
  apache2ctl start
}

setup_rocky_httpd_fpm() {
  # The image ships curl-minimal. --allowerasing lets dnf swap it for curl if a
  # dependency asks for the full package (throwaway container, so this is safe).
  dnf install -y -q --allowerasing php-fpm httpd findutils procps-ng >/dev/null
  command -v curl >/dev/null || dnf install -y -q --allowerasing curl-minimal >/dev/null
  POOL=/etc/php-fpm.d/www.conf
  echo "ServerName localhost" > /etc/httpd/conf.d/servername.conf
  # the stock pool grants the socket to apache and nginx; only apache exists in this container
  sed -i 's/^listen.acl_users = .*/listen.acl_users = apache/' "$POOL"
  plant_trap
  mkdir -p /run/php-fpm /run/httpd "$DOCROOT"
  php-fpm --daemonize
  httpd -k start
}

setup_official_fpm_nginx() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends nginx curl procps >/dev/null
  POOL=/usr/local/etc/php-fpm.d/www.conf
  cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    root $DOCROOT;
    location ~ \.php\$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_pass 127.0.0.1:9000;
    }
}
EOF
  plant_trap
  mkdir -p "$DOCROOT"
  php-fpm --daemonize
  nginx
}

plant_trap() {  # the real-world case: a finite memory_limit set BEFORE anything we add
  printf '\nphp_admin_value[memory_limit] = 1G\n' >> "$POOL"
}

# ------------------------------------------------------------------- main ---
log "Target $TARGET, advisory $ADVISORY"
if [[ "${SKIP_SETUP:-0}" != "1" ]]; then
  case "$TARGET" in
    debian-nginx-fpm)     setup_debian_nginx_fpm ;;
    ubuntu-apache-modphp) setup_ubuntu_apache_modphp ;;
    rocky-httpd-fpm)      setup_rocky_httpd_fpm ;;
    official-fpm-nginx)   setup_official_fpm_nginx ;;
    *) echo "Unknown target: $TARGET"; exit 2 ;;
  esac
fi
sleep 2
BEFORE_LIVE=$(live)
echo "  live before: $BEFORE_LIVE"
if [[ "$BEFORE_LIVE" != *"|"* ]]; then echo "PHP is not reachable over HTTP, setup failed"; exit 1; fi
snapshot > "$WORK/before.sha"

log "1. Dry run"
rc=$(run_mod "$WORK/dry.log")
cat "$WORK/dry.log"
if [[ "$rc" == "0" ]]; then ok "exit 0"; else bad "exit $rc"; fi
snapshot > "$WORK/after-dry.sha"
if cmp -s "$WORK/before.sha" "$WORK/after-dry.sha"; then ok "no file changed"
else bad "dry run changed files:"; diff "$WORK/before.sha" "$WORK/after-dry.sha" || true; fi

log "2. Apply"
rc=$(run_mod "$WORK/apply.log" --apply)
cat "$WORK/apply.log"
if [[ "$rc" == "0" ]]; then ok "exit 0"; else bad "exit $rc"; fi
if grep -q 'PASS memory_limit = -1' "$WORK/apply.log"; then ok "module reports memory_limit PASS"; else bad "no memory_limit PASS"; fi
if grep -q 'PASS upload progress off' "$WORK/apply.log"; then ok "module reports upload progress PASS"; else bad "no upload progress PASS"; fi
sleep 2
AFTER_LIVE=$(live)
echo "  live after apply: $AFTER_LIVE"
if [[ "$AFTER_LIVE" == "-1|0|"* ]]; then ok "independent check: memory_limit -1, upload progress off"
else bad "independent check: $AFTER_LIVE"; fi

log "3. Apply again (idempotent)"
rc=$(run_mod "$WORK/apply2.log" --apply)
if [[ "$rc" == "0" ]]; then ok "exit 0"; else bad "exit $rc"; cat "$WORK/apply2.log"; fi
if grep -qE '^  DO ' "$WORK/apply2.log"; then bad "second run changed something:"; grep -E '^  DO ' "$WORK/apply2.log"
else ok "nothing changed"; fi

log "4. Revert"
rc=$(run_mod "$WORK/revert.log" --revert --apply)
cat "$WORK/revert.log"
if [[ "$rc" == "0" ]]; then ok "exit 0"; else bad "exit $rc"; fi
snapshot > "$WORK/after-revert.sha"
if cmp -s "$WORK/before.sha" "$WORK/after-revert.sha"; then ok "every config file restored byte-for-byte"
else bad "config differs after revert:"; diff "$WORK/before.sha" "$WORK/after-revert.sha" || true; fi
sleep 2
REVERT_LIVE=$(live)
echo "  live after revert: $REVERT_LIVE"
if [[ "$REVERT_LIVE" == "$BEFORE_LIVE" ]]; then ok "live values back to the original"
else bad "live values: before '$BEFORE_LIVE', after revert '$REVERT_LIVE'"; fi

log "Result"
if (( FAILS == 0 )); then echo "  ALL CHECKS PASSED ($TARGET)"; exit 0; fi
echo "  $FAILS CHECK(S) FAILED ($TARGET)"; exit 1
