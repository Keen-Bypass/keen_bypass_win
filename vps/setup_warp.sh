#!/bin/bash
set -euo pipefail

# ------------------------------------------------------------
# Цвета и функции логирования
# ------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log()    { echo -e "${GREEN}[ИНФО]${NC} $1"; }
warn()   { echo -e "${YELLOW}[ВНИМАНИЕ]${NC} $1"; }
err()    { echo -e "${RED}[ОШИБКА]${NC} $1"; exit 1; }

# ------------------------------------------------------------
# Проверка прав root
# ------------------------------------------------------------
check_root() {
    if [ "$EUID" -ne 0 ]; then
        err "Этот скрипт необходимо запускать с правами root (sudo)."
    fi
}

# ------------------------------------------------------------
# Ожидание освобождения блокировки apt/dpkg
# ------------------------------------------------------------
wait_for_apt() {
    local max_wait=30
    local waited=0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
        if [ $waited -ge $max_wait ]; then
            warn "Блокировка apt/dpkg не снята за ${max_wait} секунд. Пропускаем обновление."
            return 1
        fi
        sleep 5
        waited=$((waited + 5))
    done
    return 0
}

# ------------------------------------------------------------
# Вспомогательная функция для отображения прогресса подготовки
# ------------------------------------------------------------
show_progress() {
    printf "\r\033[KПроцедура: %s" "$1"
}

# ------------------------------------------------------------
# Первоначальная настройка: обновление системы и установка пакетов
# ------------------------------------------------------------
initial_setup() {
    show_progress "ожидание освобождения apt/dpkg..."
    wait_for_apt 2>/dev/null || true

    show_progress "обновление списка пакетов (apt update)..."
    apt update -y > /dev/null 2>&1 || true

    show_progress "обновление системы (apt upgrade)..."
    apt upgrade -y > /dev/null 2>&1 || true

    local packages=(
        mtr
        nano
        curl
        ipset
        iptables
        nftables
        mc
        ncat
        nmap
        openssl
        wireguard
    )
    show_progress "установка базовых утилит..."
    apt install -y "${packages[@]}" > /dev/null 2>&1 || true

    if ! command -v wgcf &>/dev/null; then
        show_progress "установка wgcf..."
        local wgcf_url
        wgcf_url=$(curl -s https://api.github.com/repos/ViRb3/wgcf/releases/latest | \
                   grep "browser_download_url.*linux_amd64" | cut -d '"' -f 4)
        if [ -z "$wgcf_url" ]; then
            echo -e "\n${RED}[ОШИБКА]${NC} Не удалось получить URL для wgcf." >&2
            exit 1
        fi
        curl -L -o /usr/local/bin/wgcf "$wgcf_url" > /dev/null 2>&1
        chmod +x /usr/local/bin/wgcf
    fi

    echo ""
}

# ------------------------------------------------------------
# Определение основного сетевого интерфейса
# ------------------------------------------------------------
get_main_interface() {
    ip route | grep default | awk '{print $5}' | head -1
}

# ------------------------------------------------------------
# Модуль: WARP Relay
# ------------------------------------------------------------
WARP_CONF="/etc/wireguard/wg0.conf"
WARP_IPV4_ENDPOINT="162.159.192.7:500"
WARP_IPV6_ENDPOINT="[2606:4700:d0::a29f:c007]:500"
WARP_PUBKEY="bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo="
WARP_TARGET_IP="162.159.195.1"

install_warp_relay() {
    local ip_version="$1"
    local endpoint
    if [ "$ip_version" == "ipv4" ]; then
        endpoint="$WARP_IPV4_ENDPOINT"
    else
        endpoint="$WARP_IPV6_ENDPOINT"
    fi

    log "Установка WARP Relay ($ip_version)..."

    if ! command -v wgcf &>/dev/null; then
        err "wgcf не установлен. Выполните установку пакетов сначала."
    fi

    cd /etc/wireguard || err "Каталог /etc/wireguard не существует."

    if [ ! -f "wgcf-account.toml" ]; then
        log "Регистрация в Cloudflare WARP..."
        yes | wgcf register --accept-tos || err "Ошибка регистрации wgcf."
    fi

    if [ ! -f "wgcf-profile.conf" ]; then
        log "Генерация профиля wgcf..."
        wgcf generate || err "Ошибка генерации профиля."
    fi

    local priv_key wg_addr
    priv_key=$(grep "^PrivateKey" wgcf-profile.conf | awk '{print $3}')
    wg_addr=$(grep "^Address" wgcf-profile.conf | sed -E 's/^Address\s*=\s*//')

    if [ -z "$priv_key" ] || [ -z "$wg_addr" ]; then
        err "Не удалось извлечь PrivateKey или Address из wgcf-profile.conf."
    fi

    log "Используется PrivateKey: $priv_key"
    log "Используется Address: $wg_addr"

    local main_if
    main_if=$(get_main_interface)
    if [ -z "$main_if" ]; then
        err "Не удалось определить сетевой интерфейс по умолчанию."
    fi
    log "Основной интерфейс: $main_if"

    log "Создание конфигурации $WARP_CONF..."
    cat > "$WARP_CONF" <<EOF
[Interface]
PrivateKey = $priv_key
Address = $wg_addr
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
PostUp = nft add rule ip wg_nat prerouting udp dport 500 dnat to ${WARP_TARGET_IP}:500

# --- MASQUERADE ---
PostUp = nft add rule ip wg_nat postrouting oifname "$main_if" masquerade
PostUp = nft add rule ip wg_nat postrouting oifname "wg0" masquerade

PostDown = nft delete table inet wg_filter 2>/dev/null || true
PostDown = nft delete table ip wg_nat 2>/dev/null || true
PostDown = nft delete table ip6 wg_nat6 2>/dev/null || true

[Peer]
PublicKey = $WARP_PUBKEY
AllowedIPs = ${WARP_TARGET_IP}/32
Endpoint = $endpoint
PersistentKeepalive = 15
EOF

    log "Включение IP-форвардинга..."
    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1
    grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    grep -q "^net.ipv6.conf.all.forwarding=1" /etc/sysctl.conf || echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf

    log "Запуск интерфейса wg0..."
    systemctl enable wg-quick@wg0 &>/dev/null || true
    wg-quick down wg0 &>/dev/null || true
    wg-quick up wg0 || err "Не удалось поднять интерфейс wg0."

    log "WARP Relay ($ip_version) успешно установлен и запущен."
    log "Проверьте статус: wg show"
}

remove_warp_relay() {
    log "Удаление WARP Relay..."
    wg-quick down wg0 &>/dev/null || true
    systemctl disable wg-quick@wg0 &>/dev/null || true
    rm -f "$WARP_CONF"
    nft delete table inet wg_filter 2>/dev/null || true
    nft delete table ip wg_nat 2>/dev/null || true
    nft delete table ip6 wg_nat6 2>/dev/null || true
    log "WARP Relay удалён."
}

# ------------------------------------------------------------
# Управление WireGuard интерфейсом
# ------------------------------------------------------------
stop_wireguard() {
    if [ ! -f "$WARP_CONF" ]; then
        warn "Конфигурация $WARP_CONF не найдена. WireGuard, вероятно, не настроен."
        return
    fi
    log "Остановка интерфейса wg0..."
    wg-quick down wg0 && log "Интерфейс wg0 остановлен." || warn "Не удалось остановить wg0."
}

start_wireguard() {
    if [ ! -f "$WARP_CONF" ]; then
        warn "Конфигурация $WARP_CONF не найдена. Сначала настройте WARP Relay."
        return
    fi
    log "Запуск интерфейса wg0..."
    wg-quick up wg0 && log "Интерфейс wg0 запущен." || warn "Не удалось запустить wg0."
}

restart_wireguard() {
    if [ ! -f "$WARP_CONF" ]; then
        warn "Конфигурация $WARP_CONF не найдена. Сначала настройте WARP Relay."
        return
    fi
    log "Перезапуск интерфейса wg0..."
    wg-quick down wg0 &>/dev/null || true
    wg-quick up wg0 && log "Интерфейс wg0 перезапущен." || warn "Не удалось перезапустить wg0."
}

# ------------------------------------------------------------
# Получение внешних IP-адресов
# ------------------------------------------------------------
get_external_ips() {
    local ipv4 ipv6

    ipv4=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "не определён")
    ipv6=$(curl -s --max-time 3 https://api6.ipify.org 2>/dev/null || echo "не доступен")

    echo -e "Ваш IPv4: ${GREEN}${ipv4}${NC}\t\tВаш IPv6: ${GREEN}${ipv6}${NC}"
}

# ------------------------------------------------------------
# Модуль: Диагностика (iPerf)
# ------------------------------------------------------------
IPERF_PORT=5201
IPERF_PID_FILE="/var/run/iperf3.pid"
IPERF_LOG="/var/log/iperf3.log"

get_external_ips() {
    local ipv4 ipv6
    ipv4=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "не определён")
    ipv6=$(curl -s --max-time 3 https://api6.ipify.org 2>/dev/null || echo "не доступен")
    echo -e "Ваш IPv4: ${GREEN}${ipv4}${NC}\t\tВаш IPv6: ${GREEN}${ipv6}${NC}"
}

install_iperf() {
    log "Установка iperf3..."
    wait_for_apt 2>/dev/null || true
    apt install -y iperf3 || err "Не удалось установить iperf3."
    log "iperf3 установлен."
}

start_iperf_server() {
    if pgrep -f "iperf3 -s" > /dev/null; then
        warn "Сервер iperf3 уже запущен."
        return
    fi

    get_external_ips

    log "Запуск сервера iperf3 на порту $IPERF_PORT..."
    nohup iperf3 -s -p "$IPERF_PORT" > "$IPERF_LOG" 2>&1 &
    local pid=$!
    echo "$pid" > "$IPERF_PID_FILE"
    log "Сервер iperf3 запущен (PID: $pid)."

    sleep 1

    echo "-----------------------------------------------------------"
    if [ -f "$IPERF_LOG" ] && grep -q "Server listening on" "$IPERF_LOG"; then
        grep "Server listening on" "$IPERF_LOG" | head -1
    else
        echo "Server listening on $IPERF_PORT"
    fi
    echo "-----------------------------------------------------------"
}

stop_iperf_server() {
    if [ -f "$IPERF_PID_FILE" ]; then
        local pid
        pid=$(cat "$IPERF_PID_FILE")
        if kill "$pid" 2>/dev/null; then
            log "Сервер iperf3 остановлен (PID: $pid)."
            rm -f "$IPERF_PID_FILE"
        else
            warn "Не удалось остановить процесс с PID $pid. Возможно, он уже завершён."
            rm -f "$IPERF_PID_FILE"
        fi
    else
        pkill -f "iperf3 -s" && log "Все серверы iperf3 остановлены." || warn "Сервер iperf3 не найден."
    fi
}

# ------------------------------------------------------------
# Меню
# ------------------------------------------------------------
show_header() {
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}          PhotonSBP Manager${NC}"
    echo -e "${GREEN}========================================${NC}"
}

press_any_key() {
    echo
    read -n 1 -s -r -p "Нажмите любую клавишу для продолжения..."
    echo
}

wait_for_key() {
    echo
    read -n 1 -s -r -p ""
    echo
}

main_menu() {
    while true; do
        show_header
        echo "1. WARP in WARP Relay"
        echo "2. Диагностика"
        echo
        echo "0. Выход"
        echo
        read -p "Выберите пункт: " choice
        case $choice in
            1) warp_menu ;;
            2) diag_menu ;;
            0) exit 0 ;;
            *) warn "Неверный ввод. Попробуйте снова."; press_any_key ;;
        esac
    done
}

warp_menu() {
    while true; do
        show_header
        echo "--- WARP in WARP Relay ---"
        echo "1. Установить/обновить IPv4"
        echo "2. Установить/обновить IPv6"
        echo
        echo "3. Остановить WireGuard"
        echo "4. Запустить WireGuard"
        echo "5. Перезапустить WireGuard"
        echo
        echo "99. Удалить"
        echo
        echo "0. Назад"
        echo "00. Выход"
        echo
        read -p "Выберите пункт: " choice
        case $choice in
            1) install_warp_relay "ipv4"; press_any_key ;;
            2) install_warp_relay "ipv6"; press_any_key ;;
            3) stop_wireguard; press_any_key ;;
            4) start_wireguard; press_any_key ;;
            5) restart_wireguard; press_any_key ;;
            99) remove_warp_relay; press_any_key ;;
            0) break ;;
            00) exit 0 ;;
            *) warn "Неверный ввод."; press_any_key ;;
        esac
    done
}

diag_menu() {
    while true; do
        show_header
        echo "--- Диагностика ---"
        echo "1. iPerf"
        echo
        echo "0. Назад"
        echo "00. Выход"
        echo
        read -p "Выберите пункт: " choice
        case $choice in
            1) iperf_menu ;;
            0) break ;;
            00) exit 0 ;;
            *) warn "Неверный ввод."; press_any_key ;;
        esac
    done
}

iperf_menu() {
    while true; do
        show_header
        echo "--- iPerf ---"
        echo "1. Установить/обновить"
        echo
        echo "2. Остановить сервер"
        echo "3. Запустить сервер"
        echo
        echo "0. Назад"
        echo "00. Выход"
        echo
        read -p "Выберите пункт: " choice
        case $choice in
            1) install_iperf; press_any_key ;;
            2) stop_iperf_server; press_any_key ;;
            3) start_iperf_server; wait_for_key ;;
            0) break ;;
            00) exit 0 ;;
            *) warn "Неверный ввод."; press_any_key ;;
        esac
    done
}

# ------------------------------------------------------------
# Точка входа
# ------------------------------------------------------------
main() {
    check_root

    echo -e "${GREEN}Выполняется подготовка... Это может занять некоторое время.${NC}"
    initial_setup

    main_menu
}

main "$@"
