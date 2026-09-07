#!/bin/bash
# phpdev library bootstrap — sourced by bin/setup-dev-env and setup-dev-env.sh
# shellcheck shell=bash

if [ -z "${BASH_VERSION:-}" ]; then
    echo "ОШИБКА: Требуется bash"
    return 1 2>/dev/null || exit 1
fi

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Resolve repo root: prefer PHPDEV_ROOT, else directory of this file's parent (lib/ -> root)
if [ -z "${PHPDEV_ROOT:-}" ]; then
    _phpdev_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PHPDEV_ROOT="$(cd "$_phpdev_lib_dir/.." && pwd)"
fi
SCRIPT_DIR="$PHPDEV_ROOT"

USERNAME="$(whoami)"
HOME_DIR="${HOME:-/home/$USERNAME}"
WWW_DIR="$HOME_DIR/www"
BACKUP_DIR="$HOME_DIR/.config-backups"
DB_BACKUP_DIR="${BACKUP_DIR}/db"
LOG_FILE="$HOME_DIR/setup-dev-env.log"
STATE_DIR="$HOME_DIR/.config/phpdev"
STATE_FILE="$STATE_DIR/installed.env"

USER_GIT_NAME="${USER_GIT_NAME:-}"
USER_GIT_EMAIL="${USER_GIT_EMAIL:-}"
USER_DB_PASSWORD="${USER_DB_PASSWORD:-}"
SKIP_INPUT="${SKIP_INPUT:-false}"

declare -a RECOMMENDATIONS=()
declare -a POST_INSTALL_COMMANDS=()
declare -a FAILED_DOWNLOADS=()

# Log file fallback
if ! (true >> "$LOG_FILE") 2>/dev/null; then
    LOG_FILE="/tmp/setup-dev-env-${USERNAME}.log"
    (true >> "$LOG_FILE") 2>/dev/null || LOG_FILE="/dev/null"
fi

# lib/common.sh — auto-split from setup-dev-env.sh
# shellcheck shell=bash

load_versions_config() {
    local cfg="$SCRIPT_DIR/config/versions.env"
    
    # Defaults, если файла нет или ключ не задан
    PHP_SUPPORTED="${PHP_SUPPORTED:-8.1 8.2 8.3 8.4}"
    PHP_LEGACY="${PHP_LEGACY:-7.3 7.4}"
    PHP_DEFAULT="${PHP_DEFAULT:-8.4}"
    GO_VERSION="${GO_VERSION:-1.26.1}"
    MKCERT_VERSION="${MKCERT_VERSION:-v1.4.4}"
    NVM_VERSION="${NVM_VERSION:-v0.40.3}"
    MAIL_CATCHER="${MAIL_CATCHER:-mailpit}"
    MAILPIT_VERSION="${MAILPIT_VERSION:-v1.24.1}"
    OBSIDIAN_VERSION="${OBSIDIAN_VERSION:-1.5.12}"
    PHPSTORM_VERSION="${PHPSTORM_VERSION:-2024.3.1.1}"
    
    if [ -f "$cfg" ]; then
        # shellcheck disable=SC1090
        set +u
        # shellcheck source=config/versions.env
        source "$cfg"
        set -euo pipefail
    fi
    
    # Собрать URL PhpStorm, если не задан явно
    if [ -z "${PHPSTORM_URL:-}" ]; then
        PHPSTORM_URL="https://download.jetbrains.com/webide/PhpStorm-${PHPSTORM_VERSION}.tar.gz"
    fi
    
    # Массивы из пробел-разделённых строк
    # shellcheck disable=SC2206
    PHP_SUPPORTED_VERSIONS=($PHP_SUPPORTED)
    # shellcheck disable=SC2206
    PHP_LEGACY_VERSIONS=($PHP_LEGACY)
    PHP_ALL_KNOWN_VERSIONS=("${PHP_LEGACY_VERSIONS[@]}" "${PHP_SUPPORTED_VERSIONS[@]}")
}

log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    { echo "[$timestamp] [$level] $message" >> "$LOG_FILE"; } 2>/dev/null || true
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO" "$1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS" "$1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log "WARNING" "$1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR" "$1"
}

print_section() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} $1${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    log "SECTION" "=== $1 ==="
}

apt_install() {
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"; then
        return 0
    fi
    print_warning "apt не смог установить: $*"
    return 1
}

download_file() {
    local url="$1"
    local dest="$2"
    local label="${3:-$1}"
    
    rm -f "$dest" 2>/dev/null || true
    if wget --progress=bar:force "$url" -O "$dest" 2>&1; then
        if [ -f "$dest" ] && [ -s "$dest" ]; then
            return 0
        fi
    fi
    
    rm -f "$dest" 2>/dev/null || true
    print_warning "Не удалось скачать: $label"
    FAILED_DOWNLOADS+=("$label")
    return 1
}

run_optional() {
    local name="$1"
    shift
    print_info "Опциональный шаг: $name"
    if "$@"; then
        return 0
    fi
    print_warning "Опциональный шаг «$name» завершился с ошибкой — продолжаем"
    return 0
}

ensure_state_dir() {
    mkdir -p "$STATE_DIR"
}

state_set() {
    local key="$1"
    local val="$2"
    ensure_state_dir
    touch "$STATE_FILE"
    if grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${val}|" "$STATE_FILE"
    else
        echo "${key}=${val}" >> "$STATE_FILE"
    fi
}

state_list_add() {
    local key="$1"
    local item="$2"
    ensure_state_dir
    touch "$STATE_FILE"
    local current=""
    if grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
        current=$(grep "^${key}=" "$STATE_FILE" | head -1 | cut -d= -f2-)
    fi
    local x
    for x in $current; do
        if [ "$x" = "$item" ]; then
            return 0
        fi
    done
    if [ -n "$current" ]; then
        state_set "$key" "$current $item"
    else
        state_set "$key" "$item"
    fi
}

record_php_installed() {
    local version="$1"
    state_list_add "PHP_INSTALLED" "$version"
    state_set "PHP_LAST_INSTALLED" "$version"
    state_set "UPDATED_AT" "$(date -Iseconds)"
}

record_go_installed() {
    local version="$1"
    state_set "GO_INSTALLED" "$version"
    state_set "UPDATED_AT" "$(date -Iseconds)"
}

record_nvm_installed() {
    local version="$1"
    state_set "NVM_INSTALLED" "$version"
    state_set "UPDATED_AT" "$(date -Iseconds)"
}

check_ubuntu_version() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "ubuntu" ]]; then
            print_error "Этот скрипт предназначен только для Ubuntu!"
            print_info "Обнаружена ОС: $ID $VERSION_ID"
            exit 1
        fi
        
        # Проверка версии (24.04 или выше)
        local version_num=$(echo "$VERSION_ID" | cut -d. -f1)
        if [[ "$version_num" -lt 24 ]]; then
            print_warning "Скрипт оптимизирован для Ubuntu 24.04+"
            print_info "Обнаружена версия: $VERSION_ID"
            print_info "Некоторые пакеты могут быть недоступны"
            read -p "Продолжить? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        else
            print_success "Ubuntu $VERSION_ID — поддерживается"
        fi
    else
        print_warning "Не удалось определить версию ОС"
    fi
}

check_sudo() {
    if ! sudo -v &>/dev/null; then
        print_error "Требуются права sudo для выполнения скрипта"
        print_info "Запустите: sudo -v"
        exit 1
    fi
    print_success "Права sudo подтверждены"
}

check_internet() {
    print_info "Проверка интернет-соединения..."
    
    # Проверяем несколько хостов на случай если один недоступен
    local hosts=("google.com" "github.com" "ubuntu.com")
    local connected=false
    
    for host in "${hosts[@]}"; do
        if ping -c 1 -W 3 "$host" &>/dev/null; then
            connected=true
            break
        fi
    done
    
    if [ "$connected" = false ]; then
        print_error "Нет подключения к интернету!"
        print_info "Проверьте сетевое соединение и повторите попытку"
        exit 1
    fi
    
    print_success "Интернет-соединение активно"
}

run_prechecks() {
    print_section "Предварительные проверки"
    check_ubuntu_version
    check_sudo
    check_internet
    print_success "Все проверки пройдены"
}

collect_user_input() {
    print_section "Настройка параметров установки"
    
    echo -e "${CYAN}Введите данные для настройки окружения.${NC}"
    echo -e "${CYAN}Нажмите Enter для пропуска (настроите позже).${NC}"
    echo ""
    
    # Git настройки
    local current_git_name=$(git config --global user.name 2>/dev/null || echo "")
    local current_git_email=$(git config --global user.email 2>/dev/null || echo "")
    
    echo -e "${YELLOW}=== Git настройки ===${NC}"
    if [ -n "$current_git_name" ]; then
        echo -e "  Текущее имя: ${GREEN}$current_git_name${NC}"
        read -p "  Новое имя (Enter = оставить): " USER_GIT_NAME
        [ -z "$USER_GIT_NAME" ] && USER_GIT_NAME="$current_git_name"
    else
        read -p "  Ваше имя для Git: " USER_GIT_NAME
    fi
    
    if [ -n "$current_git_email" ]; then
        echo -e "  Текущий email: ${GREEN}$current_git_email${NC}"
        read -p "  Новый email (Enter = оставить): " USER_GIT_EMAIL
        [ -z "$USER_GIT_EMAIL" ] && USER_GIT_EMAIL="$current_git_email"
    else
        read -p "  Ваш email для Git: " USER_GIT_EMAIL
    fi
    
    echo ""
    
    # SSH ключ
    echo -e "${YELLOW}=== SSH ключ ===${NC}"
    if [ -f "$HOME_DIR/.ssh/id_ed25519" ]; then
        echo -e "  ${GREEN}SSH ключ уже существует${NC}"
        read -p "  Создать новый? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            GENERATE_NEW_SSH=true
        else
            GENERATE_NEW_SSH=false
        fi
    else
        read -p "  Сгенерировать SSH ключ? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            GENERATE_NEW_SSH=true
        else
            GENERATE_NEW_SSH=false
        fi
    fi
    
    echo ""
    echo -e "${GREEN}=== Параметры сохранены ===${NC}"
    echo ""
    
    log "INPUT" "Git name: $USER_GIT_NAME, Git email: $USER_GIT_EMAIL"
}

add_recommendation() {
    RECOMMENDATIONS+=("$1")
}

add_post_command() {
    POST_INSTALL_COMMANDS+=("$1")
}

show_final_summary() {
    print_section "УСТАНОВКА ЗАВЕРШЕНА"
    
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    ИТОГОВАЯ СВОДКА                             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Важные действия
    echo -e "${YELLOW}⚡ ОБЯЗАТЕЛЬНЫЕ ДЕЙСТВИЯ:${NC}"
    echo ""
    echo -e "  ${CYAN}1.${NC} Перезапустите терминал или выполните:"
    echo -e "     ${GREEN}source ~/.zshrc${NC}"
    echo ""
    echo -e "  ${CYAN}2.${NC} Для работы Docker без sudo перезайдите в систему"
    echo ""
    
    # Не удалось скачать
    if [ ${#FAILED_DOWNLOADS[@]} -gt 0 ]; then
        echo -e "${RED}❌ НЕ УДАЛОСЬ СКАЧАТЬ:${NC}"
        echo ""
        for item in "${FAILED_DOWNLOADS[@]}"; do
            echo -e "  ${RED}•${NC} $item"
        done
        echo ""
        echo -e "  ${YELLOW}Попробуйте скачать вручную или запустите скрипт повторно${NC}"
        echo ""
    fi
    
    # Рекомендации
    if [ ${#RECOMMENDATIONS[@]} -gt 0 ]; then
        echo -e "${YELLOW}📋 РЕКОМЕНДАЦИИ:${NC}"
        echo ""
        local i=1
        for rec in "${RECOMMENDATIONS[@]}"; do
            echo -e "  ${CYAN}$i.${NC} $rec"
            i=$((i + 1))
        done
        echo ""
    fi
    
    # Команды для выполнения
    echo -e "${YELLOW}🚀 ПОЛЕЗНЫЕ КОМАНДЫ:${NC}"
    echo ""
    echo -e "  ${GREEN}dev start${NC}              — запустить все сервисы"
    echo -e "  ${GREEN}dev stop${NC}               — остановить все сервисы"
    echo -e "  ${GREEN}dev status${NC}             — статус сервисов"
    echo -e "  ${GREEN}dev php 8.3${NC}            — переключить PHP на 8.3"
    echo ""
    echo -e "  ${GREEN}new-project site.test${NC}  — создать новый проект"
    echo ""
    
    # Установка Node.js
    echo -e "${YELLOW}📦 УСТАНОВКА NODE.JS:${NC}"
    echo ""
    echo -e "  ${GREEN}nvm install --lts${NC}      — установить LTS версию"
    echo -e "  ${GREEN}nvm install 20${NC}         — установить Node.js 20"
    echo ""
    
    # Настройка баз данных
    echo -e "${YELLOW}🗄️ НАСТРОЙКА БАЗ ДАННЫХ:${NC}"
    echo ""
    echo -e "  ${CYAN}MariaDB:${NC}"
    echo -e "    ${GREEN}sudo mysql_secure_installation${NC}"
    echo -e "    ${GREEN}mysql -uroot -p${NC}"
    echo ""
    echo -e "  ${CYAN}PostgreSQL:${NC}"
    echo -e "    ${GREEN}sudo -u postgres psql${NC}"
    echo -e "    ${GREEN}ALTER USER postgres WITH ENCRYPTED PASSWORD 'пароль';${NC}"
    echo ""
    
    # SSH ключ
    if [ -f "$HOME_DIR/.ssh/id_ed25519.pub" ]; then
        echo -e "${YELLOW}🔑 ВАШ SSH КЛЮЧ (добавьте в GitHub/GitLab):${NC}"
        echo ""
        echo -e "${CYAN}$(cat "$HOME_DIR/.ssh/id_ed25519.pub")${NC}"
        echo ""
    fi
    
    # URLs
    echo -e "${YELLOW}🌐 WEB-ИНТЕРФЕЙСЫ:${NC}"
    echo ""
    echo -e "  Mail UI:   ${GREEN}http://localhost:8025${NC}  ($MAIL_CATCHER)"
    echo ""
    
    # Шрифты
    echo -e "${YELLOW}🔤 ШРИФТЫ ДЛЯ ТЕРМИНАЛА:${NC}"
    echo ""
    echo -e "  Установите шрифт ${GREEN}MesloLGS NF${NC} в настройках терминала"
    echo -e "  GNOME Terminal: Preferences → Profile → Custom font"
    echo ""
    
    # Лог файл
    echo -e "${YELLOW}📄 ЛОГ УСТАНОВКИ:${NC}"
    echo ""
    echo -e "  ${GREEN}$LOG_FILE${NC}"
    echo ""
    
    # Проверка окружения
    echo -e "${YELLOW}🔍 ПРОВЕРКА ОКРУЖЕНИЯ:${NC}"
    echo ""
    echo -e "  ${GREEN}./setup-dev-env.sh health${NC}"
    echo ""
    
    echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
}

backup_config() {
    local file="$1"
    
    if [ -f "$file" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup_name="$(basename "$file").$(date +%Y%m%d_%H%M%S).bak"
        cp "$file" "$BACKUP_DIR/$backup_name"
        print_info "Бэкап создан: $BACKUP_DIR/$backup_name"
        log "BACKUP" "Создан бэкап: $file -> $BACKUP_DIR/$backup_name"
    fi
}

restore_config() {
    local original_file="$1"
    local backup_file="$2"
    
    if [ -f "$backup_file" ]; then
        sudo cp "$backup_file" "$original_file"
        print_success "Восстановлено из бэкапа: $original_file"
    else
        print_error "Бэкап не найден: $backup_file"
    fi
}

list_backups() {
    print_section "Список бэкапов"
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        ls -la "$BACKUP_DIR"
    else
        print_info "Бэкапы отсутствуют"
    fi
}

is_apt_installed() {
    dpkg -l "$1" &>/dev/null
}

is_command_exists() {
    command -v "$1" &>/dev/null
}

is_service_exists() {
    systemctl list-unit-files "$1.service" &>/dev/null
}

check_already_installed() {
    local name="$1"
    local check_cmd="$2"
    
    if eval "$check_cmd"; then
        print_warning "$name уже установлен — пропускаем"
        return 0  # уже установлен
    fi
    return 1  # не установлен
}

ask_reinstall() {
    local name="$1"
    print_warning "$name уже установлен"
    read -p "Переустановить? (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

install_from_repo() {
    local src="$1"
    local dest="$2"
    local mode="${3:-755}"
    
    if [ ! -f "$src" ]; then
        print_error "Исходник не найден: $src"
        print_info "Ожидается файл в репозитории рядом со скриптом установки"
        return 1
    fi
    
    sudo install -D -m "$mode" "$src" "$dest"
    print_success "Установлено: $dest"
    return 0
}


load_versions_config
