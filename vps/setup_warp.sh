#!/bin/bash
set -e

# ------------------------------------------------------------
# Автоматическая настройка WireGuard + WARP + nftables
# Версия: 1.0
# ------------------------------------------------------------

# --- Переменные (при необходимости измените под себя) ---
EXTERNAL_IFACE=$(ip route show default | awk '{print $5}' | head -1)  # внешний интерфейс (eth0, ens3 и т.д.)
MTU=1360

# Правила DNAT: UDP порт -> целевой адрес:порт
declare -A DNAT_RULES=(
    [4500]="162.159.195.2:4500"
    [5201]="162.159.192.2:4500"
    [500]="162.159.192.1:4500"
)

# Разрешённые IP для Peer (AllowedIPs) – из примера
ALLOWED_IPS="162.159.192.2/32"

# ------------------------------------------------------------
# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo "Пожалуйста, запустите скрипт с правами root (sudo)."
    exit 1
fi

echo "=== Обновление списка пакетов и установка WireGuard, nftables, утилит ==="
apt update
apt install -y wireguard nftables curl unzip jq

echo "=== Установка wgcf (генератор конфигурации WARP) ==="
curl -fsSL -o /tmp/wgcf.zip https://github.com/ViRb3/wgcf/releases/latest/download/wgcf_$(uname -s)_$(uname -m).zip
unzip -o /tmp/wgcf.zip -d /usr/local/bin/
chmod +x /usr/local/bin/wgcf
rm /tmp/wgcf.zip

echo "=== Регистрация WARP и генерация профиля ==="
cd /root
# Если уже есть старые файлы, удалим
rm -f wgcf-account.toml wgcf-profile.conf
echo "yes" | wgcf register
wgcf generate

if [ ! -f wgcf-profile.conf ]; then
    echo "Ошибка: не удалось сгенерировать wgcf-profile.conf"
    exit 1
fi

# Извлекаем параметры из профиля WARP
WARP_PRIVATE_KEY=$(grep -oP 'PrivateKey\s*=\s*\K.*' wgcf-profile.conf | head -1)
WARP_ADDRESS=$(grep -oP 'Address\s*=\s*\K.*' wgcf-profile.conf | head -1 | sed 's/,.*//')  # берём первый IPv4
WARP_PEER_PUBKEY=$(grep -A5 '\[Peer\]' wgcf-profile.conf | grep -oP 'PublicKey\s*=\s*\K.*')
WARP_ENDPOINT=$(grep -A5 '\[Peer\]' wgcf-profile.conf | grep -oP 'Endpoint\s*=\s*\K.*')

if [ -z "$WARP_PRIVATE_KEY" ] || [ -z "$WARP_ADDRESS" ] || [ -z "$WARP_PEER_PUBKEY" ] || [ -z "$WARP_ENDPOINT" ]; then
    echo "Ошибка: не удалось извлечь данные из wgcf-profile.conf"
    exit 1
fi

echo "=== Создание конфигурации /etc/wireguard/wg0.conf ==="
mkdir -p /etc/wireguard
# Резервная копия существующего конфига, если есть
[ -f /etc/wireguard/wg0.conf ] && cp /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak

# Генерируем PostUp/PostDown правила nftables
POSTUP_CMDS=""
POSTDOWN_CMDS=""

# Таблица IPv4 NAT
POSTUP_CMDS+="nft add table ip wg_nat 2>/dev/null || true\n"
POSTUP_CMDS+="nft add chain ip wg_nat prerouting { type nat hook prerouting priority -100 \\; } 2>/dev/null || true\n"
POSTUP_CMDS+="nft add chain ip wg_nat postrouting { type nat hook postrouting priority 100 \\; } 2>/dev/null || true\n"

# Таблица IPv6 NAT (только postrouting, если нужен)
POSTUP_CMDS+="nft add table ip6 wg_nat6 2>/dev/null || true\n"
POSTUP_CMDS+="nft add chain ip6 wg_nat6 postrouting { type nat hook postrouting priority 100 \\; } 2>/dev/null || true\n"

# Таблица фильтрации inet
POSTUP_CMDS+="nft add table inet wg_filter 2>/dev/null || true\n"
POSTUP_CMDS+="nft add chain inet wg_filter input { type filter hook input priority 0 \\; } 2>/dev/null || true\n"

# Правила INPUT – разрешить входящие UDP на нужных портах
for port in "${!DNAT_RULES[@]}"; do
    POSTUP_CMDS+="nft add rule inet wg_filter input udp dport $port accept\n"
done

# Правила DNAT
for port in "${!DNAT_RULES[@]}"; do
    target="${DNAT_RULES[$port]}"
    POSTUP_CMDS+="nft add rule ip wg_nat prerouting udp dport $port dnat to $target\n"
done

# MASQUERADE для исходящего трафика через внешний интерфейс и wg0
POSTUP_CMDS+="nft add rule ip wg_nat postrouting oifname \"$EXTERNAL_IFACE\" masquerade\n"
POSTUP_CMDS+="nft add rule ip wg_nat postrouting oifname \"wg0\" masquerade\n"

# PostDown – удаление таблиц
POSTDOWN_CMDS+="nft delete table inet wg_filter 2>/dev/null || true\n"
POSTDOWN_CMDS+="nft delete table ip wg_nat 2>/dev/null || true\n"
POSTDOWN_CMDS+="nft delete table ip6 wg_nat6 2>/dev/null || true\n"

# Запись конфигурации
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $WARP_PRIVATE_KEY
Address = $WARP_ADDRESS
MTU = $MTU

# --- Правила nftables (IPv4 NAT, DNAT, фильтрация) ---
PostUp = $POSTUP_CMDS
PostDown = $POSTDOWN_CMDS

[Peer]
PublicKey = $WARP_PEER_PUBKEY
AllowedIPs = $ALLOWED_IPS
Endpoint = $WARP_ENDPOINT
PersistentKeepalive = 15
EOF

# Заменяем \n на реальные переносы строк (PostUp/PostDown должны быть с разделителями)
sed -i '/PostUp = /{s/\\n/\nPostUp = /g; s/PostUp = $//g;}' /etc/wireguard/wg0.conf
sed -i '/PostDown = /{s/\\n/\nPostDown = /g; s/PostDown = $//g;}' /etc/wireguard/wg0.conf

echo "=== Запуск WireGuard интерфейса wg0 ==="
wg-quick down wg0 2>/dev/null || true
wg-quick up wg0

echo "=== Включение автозапуска при загрузке ==="
systemctl enable wg-quick@wg0

echo "=== Готово! ==="
echo "WireGuard интерфейс wg0 активен."
echo "Проверить статус: wg show"
echo "Проверить правила nftables: nft list ruleset"
