#!/bin/bash
# CloudSlim Agent — one-line installer
#
# Usage:
#   curl -fsSL https://cloudslim.dev/install.sh | bash
#   or:
#   bash install.sh
#
# What it does:
#   1. Detects OS and architecture
#   2. Downloads the correct binary from GitHub Releases
#   3. Installs to /usr/local/bin/cloudslim-agent
#   4. Creates systemd service
#   5. Prompts for license key
#   6. Starts the agent
#
# Works on: Ubuntu 20.04+, Debian 11+, RHEL 8+, Amazon Linux 2
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
NC='\033[0m' # No Color

REPO="Ahmadsi70/cloudslim-dist"
BINARY="cloudslim-agent"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/cloudslim"
SERVICE_FILE="/etc/systemd/system/cloudslim-agent.service"

# ── Detect OS / Arch ──────────────────────────────────────────────────

OS=$(uname -s)
ARCH=$(uname -m)

case "$OS-$ARCH" in
  Linux-x86_64)  TARGET="linux-amd64" ;;
  Linux-aarch64) TARGET="linux-arm64" ;;
  *)
    echo -e "${RED}Unsupported platform: $OS-$ARCH${NC}"
    echo "CloudSlim supports: Linux x86_64, Linux ARM64"
    exit 1
    ;;
esac

echo -e "${BOLD}CloudSlim Agent — Installer${NC}"
echo -e "${DIM}Platform: $OS-$ARCH${NC}"
echo ""

# ── Check root ────────────────────────────────────────────────────────

if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}This installer needs root privileges.${NC}"
  echo "Re-running with sudo..."
  exec sudo bash "$0" "$@"
fi

# ── Download binary ───────────────────────────────────────────────────

echo -e "${DIM}Downloading cloudslim-agent for $TARGET...${NC}"

DOWNLOAD_URL="https://github.com/$REPO/releases/latest/download/${BINARY}-${TARGET}"

# Try latest release first, fall back to a versioned URL.
if ! curl -fsSL --retry 3 --retry-delay 2 -o "/tmp/$BINARY" "$DOWNLOAD_URL"; then
  echo -e "${YELLOW}Latest release not found — trying v0.1.0...${NC}"
  DOWNLOAD_URL="https://github.com/$REPO/releases/download/v0.1.0/${BINARY}-${TARGET}"
  curl -fsSL --retry 3 --retry-delay 2 -o "/tmp/$BINARY" "$DOWNLOAD_URL"
fi

chmod +x "/tmp/$BINARY"
mv "/tmp/$BINARY" "$INSTALL_DIR/$BINARY"

echo -e "${GREEN}✓ Binary installed to $INSTALL_DIR/$BINARY${NC}"

# ── License key ───────────────────────────────────────────────────────

echo ""
echo -ne "${BOLD}Enter your CloudSlim license key: ${NC}"
read -r LICENSE_KEY

if [ -z "$LICENSE_KEY" ]; then
  echo -e "${RED}License key is required. Get one at https://cloudslim.dev${NC}"
  exit 1
fi

mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/agent.env" <<EOF
# CloudSlim Agent configuration
CLOUDSLIM_LICENSE=$LICENSE_KEY
CLOUDSLIM_ENDPOINT=https://altaria.proxy.rlwy.net:32846
CLOUDSLIM_LOG_LEVEL=info
EOF
chmod 600 "$CONFIG_DIR/agent.env"

echo -e "${GREEN}✓ License key saved to $CONFIG_DIR/agent.env${NC}"

# ── systemd service ───────────────────────────────────────────────────

cat > "$SERVICE_FILE" <<'UNITEOF'
[Unit]
Description=CloudSlim RAM Optimization Agent
Documentation=https://cloudslim.dev/docs
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudslim-agent
Restart=on-failure
RestartSec=10
Nice=-10
OOMScoreAdjust=-500

# Security hardening
NoNewPrivileges=true
ProtectHome=read-only
ProtectSystem=strict
ReadWritePaths=/var/lib/cloudslim /etc/cloudslim
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
RestrictRealtime=true
MemoryDenyWriteExecute=true
LockPersonality=true

EnvironmentFile=/etc/cloudslim/agent.env

[Install]
WantedBy=multi-user.target
UNITEOF

mkdir -p /var/lib/cloudslim

systemctl daemon-reload
systemctl enable --now cloudslim-agent

echo -e "${GREEN}✓ systemd service installed and started${NC}"

# ── Verify ─────────────────────────────────────────────────────────────

sleep 2
if systemctl is-active --quiet cloudslim-agent; then
  echo ""
  echo -e "${GREEN}${BOLD}✅ CloudSlim Agent is running!${NC}"
  echo ""
  echo -e "  View status:    ${DIM}systemctl status cloudslim-agent${NC}"
  echo -e "  View logs:      ${DIM}journalctl -u cloudslim-agent -f${NC}"
  echo -e "  Dashboard:      ${GREEN}https://app.cloudslim.dev${NC}"
else
  echo ""
  echo -e "${YELLOW}⚠ Agent installed but may not have started.${NC}"
  echo -e "  Check: ${DIM}systemctl status cloudslim-agent${NC}"
  echo -e "  Logs:  ${DIM}journalctl -u cloudslim-agent -n 50${NC}"
fi

echo ""
echo -e "${DIM}To uninstall: sudo systemctl stop cloudslim-agent && sudo rm /usr/local/bin/cloudslim-agent /etc/systemd/system/cloudslim-agent.service /etc/cloudslim/agent.env${NC}"