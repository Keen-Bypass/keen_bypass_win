#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

if [ "$EUID" -ne 0 ]; then
    err "Please run as root"
fi

MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$MAIN_IF" ]; then
    err "Cannot detect default network interface"
fi
log "Detected main interface: $MAIN_IF"

log "Installing wireguard, nftables, and wgcf..."
apt update
apt install -y wireguard nftables curl

# Установка wgcf (последняя версия)
WGCF_URL=$(curl -s https://api.github.com/repos/ViRb3/wgcf/releases/latest | grep "browser_download_url.*linux_amd64" | cut -d '"' -f 4)
if [ -z "$WGCF_URL" ]; then
    err "Failed to get wgcf download URL"
fi
curl -L -o /usr/local/bin/wgcf "$WGCF_URL"
chmod +x /usr/local/bin/wgcf

log "Registering with Cloudflare WARP..."
cd /etc/wireguard
# Генерируем конфиг wgcf, если ещё не существует
if [ ! -f "wgcf-account.toml" ]; then
    yes | /usr/local/bin/wgcf register --accept-tos
fi
/usr/local/bin/wgcf generate

# Извлекаем PrivateKey и Address из сгенерированного профиля
PRIV_KEY=$(grep "^PrivateKey" wgcf-profile.conf | awk '{print $3}')
WG_ADDR=$(grep "^Address" wgcf-profile.conf | awk '{print $3}' | cut -d ',' -f1)

if [ -z "$PRIV_KEY" ] || [ -z "$WG_ADDR" ]; then
    err "Failed to extract PrivateKey or Address from wgcf-profile.conf"
fi
log "Using WARP address: $WG_ADDR"

CONFIG="/etc/wireguard/wg0.conf"
log "Creating config at $CONFIG"
cat > "$CONFIG" <<EOF
[Interface]
PrivateKey = $PRIV_KEY
Address = $WG_ADDR
MTU = 1360

# --- IPv4 NAT table ---
PostUp = nft add table ip wg_nat 2>/dev/null || true
PostUp = nft add chain ip wg_nat prerouting { type nat hook prerouting priority -100 \; } 2>/dev/null || true
PostUp = nft add chain ip wg_nat postrouting { type nat hook postrouting priority 100 \; } 2>/dev/null || true

# --- IPv6 NAT table ---
PostUp = nft add table ip6 wg_nat6 2>/dev/null || true
PostUp = nft add chain ip6 wg_nat6 postrouting { type nat hook postrouting priority 100 \; } 2>/dev/null || true

# --- FILTER table ---
PostUp = nft add table inet wg_filter 2>/dev/null || true
PostUp = nft add chain inet wg_filter input { type filter hook input priority 0 \; } 2>/dev/null || true

# --- INPUT ---
PostUp = nft add rule inet wg_filter input udp dport 500 accept

# --- DNAT ---
PostUp = nft add rule ip wg_nat prerouting udp dport 500 dnat to 162.159.192.1:4500

# --- MASQUERADE ---
PostUp = nft add rule ip wg_nat postrouting oifname "$MAIN_IF" masquerade
PostUp = nft add rule ip wg_nat postrouting oifname "wg0" masquerade

PostDown = nft delete table inet wg_filter 2>/dev/null || true
PostDown = nft delete table ip wg_nat 2>/dev/null || true
PostDown = nft delete table ip6 wg_nat6 2>/dev/null || true

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 162.159.192.2/32
Endpoint = [2606:4700:d0::a29f:c007]:4500
PersistentKeepalive = 15
EOF

log "Enabling IP forwarding..."
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sed -i 's/#net.ipv6.conf.all.forwarding=1/net.ipv6.conf.all.forwarding=1/' /etc/sysctl.conf
grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
grep -q "^net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf || echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p

log "Enabling wg-quick@wg0 service..."
systemctl enable wg-quick@wg0

log "Starting WireGuard interface wg0..."
wg-quick up wg0

log "Setup completed successfully!"
log "Check status: wg show"
