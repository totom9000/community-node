#!/bin/bash
# PoolDaemon Community Node — One-Command Setup
# Usage: sudo ./setup.sh
set -e

echo ""
echo "  PoolDaemon Community Node Setup"
echo "  ================================"
echo ""

# Must run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo ./setup.sh"
    exit 1
fi

# Get API key from user
read -p "Paste your API key: " API_KEY
if [ -z "$API_KEY" ]; then
    echo "API key is required."
    exit 1
fi

POOL_API="https://pool.pooldeamon.com/v1/nodes/setup?api_key=${API_KEY}"

echo ""
echo "[1/4] Installing dependencies..."

# Detect OS and install
if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "Cannot detect OS"
    exit 1
fi

case $ID in
    ubuntu|debian|raspbian)
        apt-get update -qq
        apt-get install -y -qq wireguard curl haproxy jq > /dev/null 2>&1
        ;;
    fedora|centos|rhel)
        dnf install -y wireguard-tools curl haproxy jq > /dev/null 2>&1
        ;;
    *)
        echo "Unsupported OS: $ID — install WireGuard and haproxy manually, then re-run."
        exit 1
        ;;
esac
echo "  Done."

echo ""
echo "[2/4] Fetching node configuration from pool..."

SETUP=$(curl -sf "$POOL_API")
if [ $? -ne 0 ] || [ -z "$SETUP" ]; then
    echo "Failed to fetch config. Check your API key."
    exit 1
fi

NODE_ID=$(echo "$SETUP" | jq -r '.node_id')
TUNNEL_IP=$(echo "$SETUP" | jq -r '.tunnel_ip')
WG_CONFIG=$(echo "$SETUP" | jq -r '.wg_config')
REWARD_WALLET=$(echo "$SETUP" | jq -r '.reward_wallet')

if [ "$NODE_ID" = "null" ] || [ -z "$NODE_ID" ]; then
    echo "Invalid API key or node not approved yet."
    exit 1
fi

echo "  Node ID:   $NODE_ID"
echo "  Tunnel IP: $TUNNEL_IP"
echo "  Wallet:    $REWARD_WALLET"

echo ""
echo "[3/4] Setting up WireGuard tunnel..."

echo "$WG_CONFIG" > /etc/wireguard/wg-pooldeamon.conf
chmod 600 /etc/wireguard/wg-pooldeamon.conf

# Stop if already running, then start fresh via systemd
systemctl stop wg-quick@wg-pooldeamon > /dev/null 2>&1 || true
wg-quick down wg-pooldeamon > /dev/null 2>&1 || true
systemctl enable wg-quick@wg-pooldeamon > /dev/null 2>&1
systemctl start wg-quick@wg-pooldeamon

# Verify tunnel
if ping -c 1 -W 3 10.100.0.1 > /dev/null 2>&1; then
    echo "  Tunnel connected."
else
    echo "  WARNING: Cannot reach pool server through tunnel."
    echo "  Check your firewall allows UDP port 51820 outbound."
fi

echo ""
echo "[4/4] Setting up stratum relay..."

UPSTREAM="10.100.0.1"

# Configure haproxy with PROXY protocol to preserve miner IPs
cat > /etc/haproxy/haproxy.cfg << EOF
global
    log /dev/log local0
    maxconn 4096
    user haproxy
    group haproxy
    daemon

defaults
    mode tcp
    timeout connect 5s
    timeout client  300s
    timeout server  300s
    retries 3

frontend stratum_octaspace
    bind *:3333
    default_backend pool_octaspace

frontend stratum_aves
    bind *:3334
    default_backend pool_aves

frontend stratum_bitcoinii
    bind *:3335
    default_backend pool_bitcoinii

frontend stratum_larissa
    bind *:3337
    default_backend pool_larissa

backend pool_octaspace
    server pool ${UPSTREAM}:23333 send-proxy

backend pool_aves
    server pool ${UPSTREAM}:23334 send-proxy

backend pool_bitcoinii
    server pool ${UPSTREAM}:23335 send-proxy

backend pool_larissa
    server pool ${UPSTREAM}:23337 send-proxy
EOF

# Stop old socat services if upgrading
for PORT in 3333 3334 3335 3337; do
    systemctl stop pooldeamon-${PORT} > /dev/null 2>&1 || true
    systemctl disable pooldeamon-${PORT} > /dev/null 2>&1 || true
    rm -f /etc/systemd/system/pooldeamon-${PORT}.service
done
systemctl daemon-reload > /dev/null 2>&1 || true

# Start haproxy
systemctl enable haproxy > /dev/null 2>&1
systemctl restart haproxy

echo "  Relay started (haproxy with PROXY protocol)."

echo ""
echo "  ================================"
echo "  Setup complete!"
echo "  ================================"
echo ""
echo "  Node ID:       $NODE_ID"
echo "  Tunnel IP:     $TUNNEL_IP"
echo "  Reward Wallet: $REWARD_WALLET"
echo ""
echo "  Commands:"
echo "    sudo systemctl status haproxy        # Check status"
echo "    sudo journalctl -u haproxy -f        # View logs"
echo "    sudo systemctl restart haproxy       # Restart"
echo ""
echo "  Node status: https://pooldeamon.com/community-nodes"
echo ""
echo "  Open firewall ports if needed:"
echo "    sudo ufw allow 3333/tcp  # OctaSpace"
echo "    sudo ufw allow 3334/tcp  # Aves"
echo "    sudo ufw allow 3335/tcp  # BitcoinII"
echo "    sudo ufw allow 3337/tcp  # Larissa"
echo ""
