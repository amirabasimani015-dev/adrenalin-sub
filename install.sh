#!/usr/bin/env bash
# ADRENALIN subscription page installer for PasarGuard
set -euo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/YOUR_USER/adrenalin-sub/main}"
PG_DIR="${PG_DIR:-/opt/pasarguard}"
PG_DATA="${PG_DATA:-/var/lib/pasarguard}"
ENVF="$PG_DIR/.env"
TPL_DIR="$PG_DATA/templates"
TPL_FILE="$TPL_DIR/subscription/index.html"
ORIG="$TPL_FILE.orig-adrenalin"
ENV_BAK="$PG_DIR/.env.adrenalin.bak"
PING_JSON="$TPL_DIR/subscription/adr-ping.json"
PING_BIN="/usr/local/bin/adrenalin-ping"
PING_CONF="/etc/adrenalin-ping.conf"
SD_DIR="/etc/systemd/system"
CRON_FILE="/etc/cron.d/adrenalin-ping"

say(){ printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn(){ printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die(){ printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || die "با root اجرا کن: sudo bash install.sh"
[ -f "$ENVF" ] || die "$ENVF پیدا نشد. مسیر پنل را با PG_DIR بده."

setenv(){
  sed -i -E "/^[#[:space:]]*$1[[:space:]]*=/d" "$ENVF"
  printf '%s="%s"\n' "$1" "$2" >> "$ENVF"
}

restart_panel(){
  if command -v pasarguard >/dev/null 2>&1; then
    pasarguard restart -n || pasarguard restart
  elif [ -f "$PG_DIR/docker-compose.yml" ]; then
    (cd "$PG_DIR" && docker compose up -d --force-recreate)
  else
    say "پنل را دستی ریستارت کن: pasarguard restart"
  fi
}

need_cmd(){
  command -v "$1" >/dev/null 2>&1 || die "دستور $1 نصب نیست"
}

# ---------- uninstall ----------
if [ "${1:-}" = "uninstall" ]; then
  [ -f "$ENV_BAK" ] && cp -f "$ENV_BAK" "$ENVF" && say ".env از بکاپ برگشت"
  if [ -f "$ORIG" ]; then mv -f "$ORIG" "$TPL_FILE"; say "قالب قبلی برگشت"; else rm -f "$TPL_FILE"; fi
  systemctl disable --now adrenalin-ping.timer >/dev/null 2>&1 || true
  rm -f "$SD_DIR/adrenalin-ping.service" "$SD_DIR/adrenalin-ping.timer" "$CRON_FILE" "$PING_BIN" "$PING_JSON" "$PING_CONF"
  systemctl daemon-reload >/dev/null 2>&1 || true
  restart_panel
  say "حذف شد"
  exit 0
fi

# ---------- install ----------
[ -d "$PG_DATA" ] || die "$PG_DATA پیدا نشد. مسیر دیتا را با PG_DATA بده."
need_cmd curl
need_cmd python3

mkdir -p "$TPL_DIR/subscription"
[ -f "$ENV_BAK" ] || cp "$ENVF" "$ENV_BAK"

# بکاپ قالب قبلی
if [ -f "$TPL_FILE" ] && [ ! -f "$ORIG" ] && ! grep -q 'pg-links' "$TPL_FILE"; then
  cp "$TPL_FILE" "$ORIG"
fi

# ---------- دانلود HTML ----------
say "دانلود index.html از گیت‌هاب..."
TMP="$(mktemp)"
curl -fsSL "$REPO_RAW/index.html" -o "$TMP" || die "دانلود HTML ناموفق"
grep -q 'pg-links' "$TMP" || die "HTML ناقص است"
grep -q 'adr-ping' "$TMP" || die "HTML ناقص است (بدون ping)"
mv -f "$TMP" "$TPL_FILE"
chmod 644 "$TPL_FILE"
say "قالب نصب شد: $TPL_FILE"

# ---------- دانلود اسکریپت پینگ ----------
say "دانلود adrenalin-ping..."
TMPP="$(mktemp)"
curl -fsSL "$REPO_RAW/adrenalin-ping" -o "$TMPP" || die "دانلود اسکریپت پینگ ناموفق"
grep -q 'ADRENALIN ping' "$TMPP" || die "اسکریپت پینگ ناقص"
install -m 755 "$TMPP" "$PING_BIN"
rm -f "$TMPP"
say "اسکریپت پینگ نصب شد: $PING_BIN"

# ---------- کانفیگ پینگ ----------
if [ ! -f "$PING_CONF" ]; then
  cat > "$PING_CONF" <<'EOF'
# ADRENALIN ping configuration
# لینک ساب یک کاربر مخصوص (با همه گروه‌ها) برای خواندن لیست سرورها
SUB_URLS=""
# سرورهای اضافه که در ساب نیستند، مثل: EXTRA_HOSTS="1.2.3.4:443 5.6.7.8:8443"
EXTRA_HOSTS=""
EOF
  chmod 600 "$PING_CONF"
fi

# اگر کاربر لینک داد، بگذار
if [ -n "${SUB_URL:-}" ]; then
  sed -i -E 's|^SUB_URLS=.*|SUB_URLS="'"$SUB_URL"'"|' "$PING_CONF"
  say "SUB_URLS تنظیم شد"
fi

# ---------- systemd timer ----------
cat > "$SD_DIR/adrenalin-ping.service" <<EOF
[Unit]
Description=ADRENALIN server-side ping
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$PING_BIN
StandardOutput=journal
StandardError=journal
EOF

cat > "$SD_DIR/adrenalin-ping.timer" <<EOF
[Unit]
Description=Run adrenalin-ping every 30s

[Timer]
OnBootSec=20s
OnUnitActiveSec=30s
AccuracySec=5s
Persistent=false

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now adrenalin-ping.timer
systemctl start adrenalin-ping.service || true

# ---------- .env ----------
setenv CUSTOM_TEMPLATES_DIRECTORY "$TPL_DIR/"
setenv SUBSCRIPTION_PAGE_TEMPLATE "subscription/index.html"
say ".env به‌روز شد"

restart_panel
say "✅ نصب کامل شد"
echo
echo "تست پینگ:"
echo "  $PING_BIN"
echo "  cat $PING_JSON"
echo
echo "اگر لینک ساب برای پینگ نداری، بزن:"
echo "  nano $PING_CONF"
echo "  و SUB_URLS را پر کن"
