#!/bin/bash
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Warp Relay Auto-Setup Script ===${NC}"
echo "Для VPS на базе Debian/Ubuntu (WireGuard + nftables + WARP relay)"
echo ""

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Пожалуйста, запустите скрипт с правами root (sudo).${NC}"
    exit 1
fi

# Определение имени основного сетевого интерфейса
DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo -e "${YELLOW}Обнаружен сетевой интерфейс по умолчанию: $DEFAULT_IFACE${NC}"
read -p "Использовать его? (y/n, по умолчанию y): " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    read -p "Введите имя интерфейса (например, eth0, ens3): " CUSTOM_IFACE
    NET_IFACE="$CUSTOM_IFACE"
else
    NET_IFACE="$DEFAULT_IFACE"
fi
echo -e "${GREEN}Будет использован интерфейс: $NET_IFACE${NC}"

# Обновление и установка пакетов
echo -e "${YELLOW}[1/8] Обновление системы и установка WireGuard, nftables, curl...${NC}"
apt update && apt upgrade -y
apt install wireguard nftables curl resolvconf -y

# Загрузка модуля WireGuard
modprobe wireguard
echo wireguard >> /etc/modules

# Установка wgcf (для получения ключей WARP)
echo -e "${YELLOW}[2/8] Установка wgcf...${NC}"
curl -fsSL git.io/wgcf.sh -o /tmp/wgcf.sh
bash /tmp/wgcf.sh
mv wgcf /usr/local/bin/
chmod +x /usr/local/bin/wgcf

# Получение конфига WARP
echo -e "${YELLOW}[3/8] Регистрация в Cloudflare WARP и получение ключей...${NC}"
cd /etc/wireguard
wgcf register --accept-tos
wgcf generate
if [ ! -f wgcf-profile.conf ]; then
    echo -e "${RED}Не удалось получить wgcf-profile.conf. Проверьте интернет.${NC}"
    exit 1
fi

# Извлечение приватного ключа и IP из конфига WARP
WARP_PRIVATE_KEY=$(grep 'PrivateKey' wgcf-profile.conf | awk '{print $3}')
WARP_ADDRESS=$(grep 'Address' wgcf-profile.conf | awk '{print $3}' | cut -d',' -f1)
if [ -z "$WARP_PRIVATE_KEY" ] || [ -z "$WARP_ADDRESS" ]; then
    echo -e "${RED}Не удалось извлечь ключи из wgcf-profile.conf.${NC}"
    exit 1
fi
echo -e "${GREEN}WARP PrivateKey и Address получены.${NC}"

# Создание конфига wg0.conf
echo -e "${YELLOW}[4/8] Создание /etc/wireguard/wg0.conf...${NC}"
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $WARP_PRIVATE_KEY
Address = $WARP_ADDRESS
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

# --- INPUT rules ---
PostUp = nft add rule inet wg_filter input udp dport 4500 accept
PostUp = nft add rule inet wg_filter input udp dport 5201 accept
PostUp = nft add rule inet wg_filter input udp dport 500 accept

# --- DNAT to Cloudflare WARP endpoints ---
PostUp = nft add rule ip wg_nat prerouting udp dport 4500 dnat to 162.159.195.2:4500
PostUp = nft add rule ip wg_nat prerouting udp dport 5201 dnat to 162.159.192.2:4500
PostUp = nft add rule ip wg_nat prerouting udp dport 500 dnat to 162.159.192.1:4500

# --- MASQUERADE ---
PostUp = nft add rule ip wg_nat postrouting oifname "$NET_IFACE" masquerade
PostUp = nft add rule ip wg_nat postrouting oifname "wg0" masquerade

# --- Cleanup ---
PostDown = nft delete table inet wg_filter 2>/dev/null || true
PostDown = nft delete table ip wg_nat 2>/dev/null || true
PostDown = nft delete table ip6 wg_nat6 2>/dev/null || true

[Peer]
PublicKey = bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=
AllowedIPs = 162.159.192.2/32
Endpoint = [2606:4700:d0::a29f:c007]:4500
PersistentKeepalive = 15
EOF

# Если нет IPv6, заменим endpoint на IPv4
if [ ! -f /proc/net/if_inet6 ]; then
    echo -e "${YELLOW}IPv6 не обнаружен, заменяем endpoint на IPv4...${NC}"
    sed -i 's|Endpoint = \[2606:4700:d0::a29f:c007\]:4500|Endpoint = 162.159.192.1:4500|' /etc/wireguard/wg0.conf
fi

# Сохраняем публичный ключ сервера (может пригодиться клиентам)
wg genkey | tee /etc/wireguard/server_privatekey > /dev/null
wg pubkey < /etc/wireguard/server_privatekey > /etc/wireguard/server_publickey
echo -e "${GREEN}Публичный ключ вашего сервера (для клиентов): $(cat /etc/wireguard/server_publickey)${NC}"

# Включение и запуск WireGuard
echo -e "${YELLOW}[5/8] Включение автозапуска и запуск wg-quick@wg0...${NC}"
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Проверка статуса
if systemctl is-active --quiet wg-quick@wg0; then
    echo -e "${GREEN}WireGuard успешно запущен.${NC}"
else
    echo -e "${RED}Ошибка запуска WireGuard. Проверьте логи: journalctl -u wg-quick@wg0${NC}"
    exit 1
fi

# Смена порта SSH (опционально)
echo -e "${YELLOW}[6/8] Настройка SSH...${NC}"
read -p "Сменить стандартный порт SSH (22) на другой? (y/n, по умолчанию y): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    read -p "Введите новый номер порта (по умолчанию 22222): " NEW_SSH_PORT
    NEW_SSH_PORT=${NEW_SSH_PORT:-22222}
    # Проверка, что порт не занят
    if ss -tuln | grep -q ":$NEW_SSH_PORT "; then
        echo -e "${RED}Порт $NEW_SSH_PORT уже используется. Выберите другой.${NC}"
        exit 1
    fi
    sed -i "s/^#Port 22/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
    sed -i "s/^Port 22/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config || true
    # Добавить, если строки нет
    if ! grep -q "^Port" /etc/ssh/sshd_config; then
        echo "Port $NEW_SSH_PORT" >> /etc/ssh/sshd_config
    fi
    systemctl restart sshd
    echo -e "${GREEN}Порт SSH изменён на $NEW_SSH_PORT. НЕ ЗАКРЫВАЙТЕ ТЕКУЩУЮ СЕССИЮ, пока не проверите новое подключение!${NC}"
    echo -e "${YELLOW}Проверьте в новом терминале: ssh -p $NEW_SSH_PORT пользователь@$(curl -s ifconfig.me)${NC}"
    read -p "Убедитесь, что подключение работает, затем нажмите Enter для продолжения..."
else
    echo -e "${YELLOW}Порт SSH оставлен 22. Рекомендуется сменить его позже.${NC}"
fi

# Финальные сообщения
echo -e "${GREEN}[7/8] Настройка завершена.${NC}"
echo "=== Сводка ==="
echo "Сетевой интерфейс: $NET_IFACE"
echo "WARP IP сервера: $WARP_ADDRESS"
echo "Публичный ключ сервера (для клиентов): $(cat /etc/wireguard/server_publickey)"
echo "Релейные порты: 4500, 5201, 500 (UDP)"
echo ""

echo -e "${YELLOW}[8/8] Система будет перезагружена через 10 секунд для проверки автозапуска...${NC}"
echo "Нажмите Ctrl+C, чтобы отменить перезагрузку."
sleep 10
reboot
