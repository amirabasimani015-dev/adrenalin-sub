# ADRENALIN Subscription Page for PasarGuard

Custom subscription page for [PasarGuard](https://github.com/PasarGuard/panel):
usage stats, QR / copy for every config, **WireGuard `.conf` download / copy / QR**,
and **latency measured on the server** (TCP for xray protocols, ICMP for WireGuard/UDP).

## Install (on the panel server, as root)

```bash
SUB_URL="https://your.domain:8000/sub/PING_USER_TOKEN" \
  bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/install.sh)
```

`SUB_URL` is the subscription link of a dedicated user that has all groups; it is only
used to learn the server list for the ping. Without it, set `SUB_URLS` later in
`/etc/adrenalin-ping.conf`.

Custom paths: `PG_DIR=/opt/pasarguard PG_DATA=/var/lib/pasarguard`.

## Uninstall

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USER/YOUR_REPO/main/install.sh) uninstall
```

## Files

- `install.sh` – installer (contains the page itself, nothing else is needed)
- `index.html` – the same page, for manual install / editing
- `RAHNAMA.txt` – full guide (Persian)

The QR generator embedded in the page is [qrcode-generator](https://github.com/kazuhikoarase/qrcode-generator) (MIT, © Kazuhiko Arase).
