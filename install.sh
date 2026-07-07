#!/bin/bash
set -e

INSTALL_DIR=/opt/resource-kuma
DATA_DIR=/var/lib/resource-kuma
DASH_DIR="$INSTALL_DIR/dashboard"

echo "==> Installing resource-kuma..."

# Copy files
mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$DASH_DIR"
cp collect.sh "$INSTALL_DIR/collect.sh"
chmod +x "$INSTALL_DIR/collect.sh"
cp dashboard/index.html "$DASH_DIR/index.html"

# Symlink data.json into dashboard so it's served alongside index.html
ln -sf "$DATA_DIR/data.json" "$DASH_DIR/data.json"

# Systemd units
cp systemd/resource-kuma-collect.service /etc/systemd/system/
cp systemd/resource-kuma-collect.timer   /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now resource-kuma-collect.timer

echo ""
echo "==> Done. Collector running every 30s."
echo "    Dashboard files: $DASH_DIR"
echo "    Data file:       $DATA_DIR/data.json"
echo ""
echo "    Serve the dashboard with any static file server pointed at $DASH_DIR"
echo "    e.g. Caddy:  reverse_proxy + file_server, or just: python3 -m http.server 7777 -d $DASH_DIR"
