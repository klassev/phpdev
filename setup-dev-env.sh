#!/bin/bash

# Проверка что скрипт запущен через bash (не sh/dash)
if [ -z "$BASH_VERSION" ]; then
    echo "ОШИБКА: Этот скрипт требует bash!"
    echo "Запустите: bash $0 $*"
    echo "Или: chmod +x $0 && ./$0 $*"
    exit 1
fi

#===============================================================================
# Скрипт настройки DEV окружения для Ubuntu 24.04
#===============================================================================
# Автор: klassev
# Описание: Автоматизированная установка и настройка dev-окружения
# Включает: Apache, Nginx, PHP (8.1, 8.2, 8.3, 8.4), MariaDB, PostgreSQL,
#           Go, MailHog, Docker, Composer, Node.js (NVM), ZSH + Oh My Zsh
#
# ВАЖНО: PHP 7.x более недоступен для Ubuntu 24.04!
#        Используйте Docker для старых проектов.
#===============================================================================

set -e  # Прерывать выполнение при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # Без цвета

# Переменные
USERNAME=$(whoami)
HOME_DIR="/home/$USERNAME"
WWW_DIR="$HOME_DIR/www"
BACKUP_DIR="$HOME_DIR/.config-backups"
LOG_FILE="$HOME_DIR/setup-dev-env.log"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Версии софта
GO_VERSION="1.24.4"
MKCERT_VERSION="v1.4.4"
NVM_VERSION="v0.40.3"

# Пользовательские параметры (заполняются в начале установки)
USER_GIT_NAME=""
USER_GIT_EMAIL=""
USER_DB_PASSWORD=""
SKIP_INPUT=false

# Массив для сбора рекомендаций
declare -a RECOMMENDATIONS=()
declare -a POST_INSTALL_COMMANDS=()
declare -a FAILED_DOWNLOADS=()

#===============================================================================
# Логирование
#===============================================================================
# Создание лог-файла
touch "$LOG_FILE"

# Функция логирования (пишет и в консоль, и в файл)
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Функция для вывода сообщений
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

#===============================================================================
# Проверки перед запуском
#===============================================================================

# Проверка версии Ubuntu
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

# Проверка прав sudo
check_sudo() {
    if ! sudo -v &>/dev/null; then
        print_error "Требуются права sudo для выполнения скрипта"
        print_info "Запустите: sudo -v"
        exit 1
    fi
    print_success "Права sudo подтверждены"
}

# Проверка интернет-соединения
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

# Запуск всех проверок
run_prechecks() {
    print_section "Предварительные проверки"
    check_ubuntu_version
    check_sudo
    check_internet
    print_success "Все проверки пройдены"
}

#===============================================================================
# Сбор параметров от пользователя в начале установки
#===============================================================================
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

#===============================================================================
# Добавление рекомендации в список
#===============================================================================
add_recommendation() {
    RECOMMENDATIONS+=("$1")
}

add_post_command() {
    POST_INSTALL_COMMANDS+=("$1")
}

#===============================================================================
# Вывод итоговой сводки после установки
#===============================================================================
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
            ((i++))
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
    echo -e "  MailHog:   ${GREEN}http://localhost:8025${NC}"
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

#===============================================================================
# Резервное копирование конфигов
#===============================================================================
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

# Функция восстановления из бэкапа
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

# Показать список бэкапов
list_backups() {
    print_section "Список бэкапов"
    if [ -d "$BACKUP_DIR" ] && [ "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        ls -la "$BACKUP_DIR"
    else
        print_info "Бэкапы отсутствуют"
    fi
}

#===============================================================================
# Функции проверки установленного софта
#===============================================================================

# Проверка установлен ли пакет apt
is_apt_installed() {
    dpkg -l "$1" &>/dev/null
}

# Проверка существует ли команда
is_command_exists() {
    command -v "$1" &>/dev/null
}

# Проверка установлен ли сервис systemd
is_service_exists() {
    systemctl list-unit-files "$1.service" &>/dev/null
}

# Универсальная проверка с выводом сообщения
check_already_installed() {
    local name="$1"
    local check_cmd="$2"
    
    if eval "$check_cmd"; then
        print_warning "$name уже установлен — пропускаем"
        return 0  # уже установлен
    fi
    return 1  # не установлен
}

# Спросить пользователя о переустановке
ask_reinstall() {
    local name="$1"
    print_warning "$name уже установлен"
    read -p "Переустановить? (y/n): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

#===============================================================================
# Функция: Обновление системы
#===============================================================================
update_system() {
    print_section "Обновление системы"
    
    sudo apt update
    sudo apt upgrade -y
    
    # Обновление snap пакетов
    # Если snap-store блокирует обновление, завершаем его процесс
    if pgrep -x "snap-store" > /dev/null; then
        print_warning "snap-store запущен, закрываем для обновления..."
        pkill snap-store || true
        sleep 2
    fi
    
    sudo snap refresh || print_warning "Не удалось обновить snap пакеты"
    
    print_success "Система обновлена"
}

#===============================================================================
# Функция: Установка базовых пакетов
#===============================================================================
install_base_packages() {
    print_section "Установка базовых пакетов"
    
    # Исправление возможных сломанных пакетов перед установкой
    sudo apt --fix-broken install -y || true
    
    # Основные утилиты (без libdvd-pkg — он устанавливается отдельно)
    sudo apt install -y \
        aptitude \
        gedit \
        mc \
        nano \
        rar \
        unrar \
        htop \
        git \
        openssh-server \
        openssh-client \
        libavcodec-extra \
        gscan2pdf \
        synaptic \
        gdebi \
        dconf-editor \
        p7zip-rar \
        arj \
        gnome-shell-extensions \
        libreoffice \
        transmission \
        vlc \
        gimp \
        neofetch \
        curl \
        wget \
        fonts-powerline
    
    # Сетевые инструменты и расширения GNOME
    sudo apt install -y \
        network-manager-openconnect \
        network-manager-openconnect-gnome \
        bashtop \
        chrome-gnome-shell \
        gnome-shell-extension-manager \
        gcc \
        libtool \
        libssl-dev \
        libc-dev \
        libjpeg-turbo8-dev \
        libpng-dev \
        libtiff5-dev \
        cups \
        printer-driver-gutenprint \
        gnome-tweaks
    
    # Установка libdvd-pkg отдельно (требует интерактивной настройки)
    print_info "Установка libdvd-pkg (для воспроизведения DVD)..."
    # Предварительно принимаем лицензию
    echo "libdvd-pkg libdvd-pkg/first-install note" | sudo debconf-set-selections
    echo "libdvd-pkg libdvd-pkg/post-invoke_hook-install boolean true" | sudo debconf-set-selections
    
    if sudo DEBIAN_FRONTEND=noninteractive apt install -y libdvd-pkg; then
        sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure libdvd-pkg || true
        print_success "libdvd-pkg установлен"
    else
        print_warning "libdvd-pkg не удалось установить автоматически"
        print_info "Установите вручную позже: sudo apt install libdvd-pkg && sudo dpkg-reconfigure libdvd-pkg"
    fi
    
    # Финальное исправление зависимостей
    sudo apt --fix-broken install -y || true
    
    print_success "Базовые пакеты установлены"
}

#===============================================================================
# Функция: Установка и настройка ZSH + Oh My Zsh + Powerlevel10k
#===============================================================================
install_zsh() {
    print_section "Установка ZSH и Oh My Zsh"
    
    # Установка ZSH
    sudo apt install -y zsh
    
    # Установка Oh My Zsh (неинтерактивно)
    if [ ! -d "$HOME_DIR/.oh-my-zsh" ]; then
        print_info "Установка Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        print_warning "Oh My Zsh уже установлен"
    fi
    
    # Установка Powerlevel10k
    if [ ! -d "$HOME_DIR/powerlevel10k" ]; then
        print_info "Установка Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME_DIR/powerlevel10k"
    fi
    
    # Добавление темы в .zshrc если её там ещё нет
    if ! grep -q "powerlevel10k.zsh-theme" "$HOME_DIR/.zshrc" 2>/dev/null; then
        echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> "$HOME_DIR/.zshrc"
    fi
    
    # Установка плагинов для ZSH
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME_DIR/.oh-my-zsh/custom}"
    
    # Autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi
    
    # Syntax highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi
    
    # Обновление плагинов в .zshrc
    if grep -q "^plugins=" "$HOME_DIR/.zshrc"; then
        sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME_DIR/.zshrc"
    fi
    
    # Смена shell на ZSH
    if [ "$SHELL" != "/usr/bin/zsh" ]; then
        print_info "Смена shell на ZSH..."
        chsh -s $(which zsh)
    fi
    
    print_success "ZSH установлен и настроен"
    print_warning "Для настройки Powerlevel10k перезапустите терминал"
    print_info "Скачайте шрифты Meslo Nerd Font: https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k"
}

#===============================================================================
# Функция: Установка Apache2
#===============================================================================
install_apache() {
    print_section "Установка Apache2"
    
    if is_command_exists apache2; then
        print_warning "Apache2 уже установлен: $(apache2 -v | head -1)"
        print_info "Пропускаем установку"
        return 0
    fi
    
    sudo apt install -y apache2 libapache2-mpm-itk
    
    # Включение необходимых модулей
    sudo a2enmod rewrite
    sudo a2enmod ssl
    sudo a2enmod proxy_fcgi
    
    # Изменение портов Apache (чтобы не конфликтовал с Nginx)
    # Apache: 8080, 8443
    # Nginx: 80, 443
    backup_config "/etc/apache2/ports.conf"
    
    sudo tee /etc/apache2/ports.conf > /dev/null << 'PORTSCONF'
# Apache ports (изменено чтобы не конфликтовать с Nginx)
# Nginx использует 80 и 443
# Apache использует 8080 и 8443

Listen 8080

<IfModule ssl_module>
    Listen 8443
</IfModule>

<IfModule mod_gnutls.c>
    Listen 8443
</IfModule>
PORTSCONF
    
    # Обновление default site для нового порта
    sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf
    
    # Отключение автозапуска
    sudo systemctl disable apache2.service
    
    print_success "Apache2 установлен"
    print_info "Порты Apache: HTTP=8080, HTTPS=8443"
    print_info "Порты Nginx: HTTP=80, HTTPS=443"
    print_info "Для запуска: sudo systemctl start apache2"
}

#===============================================================================
# Функция: Установка PHP (множество версий)
#===============================================================================
install_php() {
    print_section "Установка PHP (7.3, 7.4, 8.1, 8.2, 8.3, 8.4)"
    
    # Проверка установленных версий PHP
    local installed_versions=""
    for v in 7.3 7.4 8.1 8.2 8.3 8.4; do
        if is_command_exists "php$v"; then
            installed_versions+="$v "
        fi
    done
    
    if [ -n "$installed_versions" ]; then
        print_warning "PHP уже установлен: версии $installed_versions"
        print_info "Текущая версия CLI: $(php -v | head -1)"
        print_info "Пропускаем установку PHP"
        return 0
    fi
    
    # Добавление репозитория Ondřej Surý для PHP
    sudo add-apt-repository -y ppa:ondrej/php
    sudo apt update
    
    # PHP 7.3 (EOL — может быть недоступен для Ubuntu 24.04)
    print_info "Установка PHP 7.3..."
    if apt-cache show php7.3-fpm &>/dev/null; then
        sudo apt install -y php7.3-{cli,fpm,common,bcmath,bz2,curl,gd,gmp,intl,mbstring,mysql,opcache,pgsql,readline,xml,zip,sqlite3,xdebug,imap,gettext,dev} \
            libapache2-mod-php7.3 || \
            print_warning "PHP 7.3 не удалось установить"
    else
        print_warning "PHP 7.3 недоступен для вашей версии Ubuntu"
    fi
    
    # PHP 7.4 (EOL — может быть недоступен для Ubuntu 24.04)
    print_info "Установка PHP 7.4..."
    if apt-cache show php7.4-fpm &>/dev/null; then
        sudo apt install -y php7.4-{cli,fpm,common,bcmath,bz2,curl,gd,gmp,intl,mbstring,mysql,opcache,pgsql,readline,xml,zip,sqlite3,xdebug,imap,gettext,dev,json} \
            libapache2-mod-php7.4 || \
            print_warning "PHP 7.4 не удалось установить"
    else
        print_warning "PHP 7.4 недоступен для вашей версии Ubuntu"
    fi
    
    # PHP 8.1 (LTS до ноября 2025)
    print_info "Установка PHP 8.1..."
    sudo apt install -y php8.1-{cli,fpm,common,bcmath,bz2,curl,gd,gmp,intl,mbstring,mysql,opcache,pgsql,readline,xml,zip,sqlite3,xdebug,imap,gettext,dev} \
        libapache2-mod-php8.1 || \
        print_warning "PHP 8.1 не удалось установить"
    
    # PHP 8.2
    print_info "Установка PHP 8.2..."
    sudo apt install -y php8.2-{cli,fpm,common,bcmath,bz2,curl,gd,gmp,intl,mbstring,mysql,opcache,pgsql,readline,xml,zip,sqlite3,xdebug,imap,gettext,dev} \
        gcc make autoconf libc-dev pkg-config libapache2-mod-php8.2
    
    # PHP 8.3
    print_info "Установка PHP 8.3..."
    sudo apt install -y php8.3-{cli,fpm,common,bcmath,bz2,curl,gd,gmp,intl,mbstring,mysql,opcache,pgsql,readline,xml,zip,sqlite3,xdebug,imap,gettext,dev} \
        libapache2-mod-php8.3 || \
        print_warning "PHP 8.3 не удалось установить"
    
    # PHP 8.4
    print_info "Установка PHP 8.4..."
    sudo apt install -y php8.4-{cli,fpm,common,bcmath,bz2,curl,gd,gmp,intl,mbstring,mysql,opcache,pgsql,readline,xml,zip,sqlite3,xdebug} \
        libapache2-mod-php8.4 || \
        print_warning "PHP 8.4 не удалось установить"
    
    # Отключение автозапуска PHP-FPM сервисов
    for version in 7.3 7.4 8.1 8.2 8.3 8.4; do
        sudo systemctl disable "php${version}-fpm.service" 2>/dev/null || true
    done
    
    print_success "PHP установлен"
    print_info "Для переключения версии PHP: sudo update-alternatives --config php"
    print_warning ""
    print_warning "=== ВНИМАНИЕ: PHP 7.3 и 7.4 достигли EOL ==="
    print_warning "Они больше не получают обновления безопасности."
    print_warning "Используйте только для поддержки legacy-проектов."
}

#===============================================================================
# Функция: Настройка PHP-FPM для Nginx
#===============================================================================
configure_php_fpm() {
    print_section "Настройка PHP-FPM"
    
    # Настройка каждой версии PHP-FPM на свой порт
    # PHP 7.3 -> 9073
    # PHP 7.4 -> 9074
    # PHP 8.1 -> 9081
    # PHP 8.2 -> 9082
    # PHP 8.3 -> 9083
    # PHP 8.4 -> 9084
    
    for version in 7.3 7.4 8.1 8.2 8.3 8.4; do
        port="90${version//./}"
        conf_file="/etc/php/${version}/fpm/pool.d/www.conf"
        
        if [ -f "$conf_file" ]; then
            print_info "Настройка PHP ${version}-FPM на порт $port..."
            
            # Резервное копирование перед изменением
            backup_config "$conf_file"
            
            # Замена пользователя на текущего
            sudo sed -i "s/www-data/$USERNAME/g" "$conf_file"
            
            # Замена сокета на TCP порт
            sudo sed -i "s|listen = /run/php/php${version}-fpm.sock|listen = 127.0.0.1:$port|g" "$conf_file"
        fi
    done
    
    # Перезапуск PHP-FPM сервисов
    for version in 7.3 7.4 8.1 8.2 8.3 8.4; do
        sudo /etc/init.d/php${version}-fpm restart 2>/dev/null || true
    done
    
    print_success "PHP-FPM настроен"
    print_info "Порты PHP-FPM: 8.1→9081, 8.2→9082, 8.3→9083, 8.4→9084"
}

#===============================================================================
# Функция: Установка mkcert для локальных SSL сертификатов
#===============================================================================
install_mkcert() {
    print_section "Установка mkcert"
    
    if is_command_exists mkcert; then
        print_warning "mkcert уже установлен"
        print_info "Пропускаем установку"
        return 0
    fi
    
    sudo apt install -y libnss3-tools
    
    # Скачивание mkcert
    wget -q "https://github.com/FiloSottile/mkcert/releases/download/${MKCERT_VERSION}/mkcert-${MKCERT_VERSION}-linux-amd64" -O mkcert
    chmod +x mkcert
    sudo mv mkcert /usr/local/bin/
    
    # Установка локального CA
    mkcert -install
    
    print_success "mkcert установлен"
    print_info "Использование: mkcert example.test '*.example.test' localhost 127.0.0.1"
}

#===============================================================================
# Функция: Установка Go
#===============================================================================
install_go() {
    print_section "Установка Go $GO_VERSION"
    
    if is_command_exists go; then
        local current_version=$(go version | awk '{print $3}')
        print_warning "Go уже установлен: $current_version"
        print_info "Пропускаем установку"
        return 0
    fi
    
    cd /tmp
    
    # Скачивание Go
    print_info "Скачивание Go ${GO_VERSION}..."
    wget --progress=bar:force "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" 2>&1 || true
    
    if [ ! -f "go${GO_VERSION}.linux-amd64.tar.gz" ] || [ ! -s "go${GO_VERSION}.linux-amd64.tar.gz" ]; then
        print_warning "Не удалось скачать Go"
        FAILED_DOWNLOADS+=("Go ${GO_VERSION} — https://go.dev/dl/")
        return 1
    fi
    
    # Удаление старой версии и установка новой
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go${GO_VERSION}.linux-amd64.tar.gz"
    rm "go${GO_VERSION}.linux-amd64.tar.gz"
    
    # Добавление Go в PATH
    GO_ENV="
# Go configuration
export GOROOT=/usr/local/go
export GOPATH=\$HOME/go
export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH
"
    
    # Добавление в .zshrc если ещё не добавлено
    if ! grep -q "GOROOT" "$HOME_DIR/.zshrc" 2>/dev/null; then
        echo "$GO_ENV" >> "$HOME_DIR/.zshrc"
    fi
    
    # Добавление в .bashrc для совместимости
    if ! grep -q "GOROOT" "$HOME_DIR/.bashrc" 2>/dev/null; then
        echo "$GO_ENV" >> "$HOME_DIR/.bashrc"
    fi
    
    # Экспорт для текущей сессии
    export GOROOT=/usr/local/go
    export GOPATH=$HOME_DIR/go
    export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
    
    print_success "Go установлен"
    /usr/local/go/bin/go version
}

#===============================================================================
# Функция: Установка MailHog
#===============================================================================
install_mailhog() {
    print_section "Установка MailHog"
    
    if [ -f "$HOME_DIR/go/bin/MailHog" ]; then
        print_warning "MailHog уже установлен"
        print_info "Пропускаем установку"
        return 0
    fi
    
    # Проверка что Go установлен
    if ! is_command_exists go; then
        print_error "Go не установлен. Сначала установите Go."
        return 1
    fi
    
    # Экспорт переменных Go для текущей сессии
    export GOROOT=/usr/local/go
    export GOPATH=$HOME_DIR/go
    export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
    
    # Установка MailHog
    go install github.com/mailhog/MailHog@latest
    
    # Установка mhsendmail
    if ! is_command_exists mhsendmail; then
        wget -q "https://github.com/mailhog/mhsendmail/releases/download/v0.2.0/mhsendmail_linux_amd64" -O /tmp/mhsendmail
        sudo chmod +x /tmp/mhsendmail
        sudo mv /tmp/mhsendmail /usr/local/bin/mhsendmail
    fi
    
    print_success "MailHog установлен"
    print_info "Запуск MailHog: ~/go/bin/MailHog"
    print_info "Web UI: http://localhost:8025"
    print_info "SMTP: localhost:1025"
}

#===============================================================================
# Функция: Настройка Xdebug для PHP
#===============================================================================
configure_xdebug() {
    print_section "Настройка Xdebug"
    
    XDEBUG_CONFIG="[xdebug]
xdebug.mode=debug
xdebug.start_with_request=yes
xdebug.client_host=127.0.0.1
xdebug.client_port=9003
xdebug.idekey=PHPSTORM
xdebug.log_level=0
"
    
    # Настройка Xdebug для каждой версии PHP
    for version in 7.3 7.4 8.1 8.2 8.3 8.4; do
        xdebug_ini="/etc/php/${version}/mods-available/xdebug.ini"
        if [ -f "$xdebug_ini" ]; then
            print_info "Настройка Xdebug для PHP $version..."
            echo "$XDEBUG_CONFIG" | sudo tee "$xdebug_ini" > /dev/null
        fi
    done
    
    print_success "Xdebug настроен"
}

#===============================================================================
# Функция: Настройка sendmail_path для MailHog
#===============================================================================
configure_php_mailhog() {
    print_section "Настройка PHP для MailHog"
    
    for version in 7.3 7.4 8.1 8.2 8.3 8.4; do
        for ini_path in "/etc/php/${version}/cli/php.ini" "/etc/php/${version}/fpm/php.ini" "/etc/php/${version}/apache2/php.ini"; do
            if [ -f "$ini_path" ]; then
                # Добавление или замена sendmail_path
                if grep -q "^sendmail_path" "$ini_path"; then
                    sudo sed -i 's|^sendmail_path.*|sendmail_path = /usr/local/bin/mhsendmail|' "$ini_path"
                else
                    echo "sendmail_path = /usr/local/bin/mhsendmail" | sudo tee -a "$ini_path" > /dev/null
                fi
            fi
        done
    done
    
    print_success "PHP настроен для использования MailHog"
}

#===============================================================================
# Функция: Установка MariaDB
#===============================================================================
install_mariadb() {
    print_section "Установка MariaDB"
    
    if is_command_exists mariadb; then
        print_warning "MariaDB уже установлен: $(mariadb --version)"
        print_info "Пропускаем установку"
        return 0
    fi
    
    sudo apt install -y mariadb-server mariadb-client
    
    # Отключение автозапуска
    sudo systemctl disable mariadb.service
    
    print_success "MariaDB установлен"
    mariadb --version
    
    add_recommendation "Настройте MariaDB: sudo mysql_secure_installation"
}

#===============================================================================
# Функция: Установка PostgreSQL
#===============================================================================
install_postgresql() {
    print_section "Установка PostgreSQL"
    
    if is_command_exists psql; then
        print_warning "PostgreSQL уже установлен: $(psql --version)"
        print_info "Пропускаем установку"
        return 0
    fi
    
    sudo apt install -y postgresql postgresql-client
    
    # Отключение автозапуска
    sudo systemctl disable postgresql.service
    
    print_success "PostgreSQL установлен"
    
    add_recommendation "Установите пароль PostgreSQL: sudo -u postgres psql → ALTER USER postgres WITH ENCRYPTED PASSWORD 'пароль';"
}

#===============================================================================
# Функция: Установка Redis
#===============================================================================
install_redis() {
    print_section "Установка Redis"
    
    if is_command_exists redis-server; then
        print_warning "Redis уже установлен: $(redis-server --version)"
        print_info "Пропускаем установку"
        return 0
    fi
    
    sudo apt install -y redis-server redis-tools
    
    # Резервное копирование конфига
    backup_config "/etc/redis/redis.conf"
    
    # Настройка для разработки (слушать localhost)
    sudo sed -i 's/^supervised no/supervised systemd/' /etc/redis/redis.conf
    
    # Отключение автозапуска
    sudo systemctl disable redis-server.service
    
    print_success "Redis установлен"
    redis-server --version
    
    print_info "Для запуска: sudo systemctl start redis-server"
    print_info "Проверка: redis-cli ping (ответ: PONG)"
    
    # Установка PHP расширения для Redis
    print_info "Установка PHP расширений для Redis..."
    for version in 7.3 7.4 8.1 8.2 8.3 8.4; do
        sudo apt install -y "php${version}-redis" 2>/dev/null || true
    done
    
    print_success "PHP расширения Redis установлены"
}

#===============================================================================
# Функция: Установка Memcached
#===============================================================================
install_memcached() {
    print_section "Установка Memcached"
    
    if is_command_exists memcached; then
        print_warning "Memcached уже установлен: $(memcached -h | head -1)"
        print_info "Пропускаем установку"
        return 0
    fi
    
    sudo apt install -y memcached libmemcached-tools
    
    # Отключение автозапуска
    sudo systemctl disable memcached.service
    
    print_success "Memcached установлен"
    
    print_info "Для запуска: sudo systemctl start memcached"
    print_info "Проверка: echo stats | nc localhost 11211"
    
    # Установка PHP расширения для Memcached
    print_info "Установка PHP расширений для Memcached..."
    for version in 7.3 7.4 8.1 8.2 8.3 8.4; do
        sudo apt install -y "php${version}-memcached" 2>/dev/null || true
    done
    
    print_success "PHP расширения Memcached установлены"
}

#===============================================================================
# Функция: Установка шрифтов Meslo Nerd Font
#===============================================================================
install_meslo_fonts() {
    print_section "Установка шрифтов Meslo Nerd Font"
    
    local fonts_dir="$HOME_DIR/.local/share/fonts"
    mkdir -p "$fonts_dir"
    
    cd /tmp
    
    # URL шрифтов Meslo из репозитория Powerlevel10k
    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    local fonts=(
        "MesloLGS%20NF%20Regular.ttf"
        "MesloLGS%20NF%20Bold.ttf"
        "MesloLGS%20NF%20Italic.ttf"
        "MesloLGS%20NF%20Bold%20Italic.ttf"
    )
    
    print_info "Скачивание шрифтов..."
    for font in "${fonts[@]}"; do
        local decoded_font=$(echo "$font" | sed 's/%20/ /g')
        if [ ! -f "$fonts_dir/$decoded_font" ]; then
            wget -q "$base_url/$font" -O "$fonts_dir/$decoded_font" && \
                print_info "  ✓ $decoded_font" || \
                print_warning "  ✗ Не удалось скачать $decoded_font"
        else
            print_info "  ● $decoded_font (уже установлен)"
        fi
    done
    
    # Обновление кэша шрифтов
    fc-cache -f "$fonts_dir"
    
    print_success "Шрифты Meslo Nerd Font установлены"
    print_warning "Установите шрифт 'MesloLGS NF' в настройках терминала!"
    print_info "GNOME Terminal: Preferences → Profile → Custom font → MesloLGS NF"
}

#===============================================================================
# Функция: Health Check — проверка работоспособности окружения
#===============================================================================
health_check() {
    print_section "Health Check — проверка окружения"
    
    local all_ok=true
    
    echo -e "${CYAN}=== Системная информация ===${NC}"
    echo "  ОС: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "  Ядро: $(uname -r)"
    echo "  Пользователь: $USERNAME"
    echo ""
    
    echo -e "${CYAN}=== Проверка установленного софта ===${NC}"
    
    # PHP
    if command -v php &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} PHP: $(php -v | head -1 | cut -d' ' -f2)"
    else
        echo -e "  ${RED}✗${NC} PHP не установлен"
        all_ok=false
    fi
    
    # Composer
    if command -v composer &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Composer: $(composer --version 2>/dev/null | cut -d' ' -f3)"
    else
        echo -e "  ${YELLOW}○${NC} Composer не установлен"
    fi
    
    # Node.js
    if command -v node &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Node.js: $(node -v)"
    else
        echo -e "  ${YELLOW}○${NC} Node.js не установлен (используйте: nvm install --lts)"
    fi
    
    # Go
    if command -v go &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Go: $(go version | cut -d' ' -f3)"
    else
        echo -e "  ${YELLOW}○${NC} Go не установлен"
    fi
    
    # Docker
    if command -v docker &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
        # Проверка работы без sudo
        if docker ps &>/dev/null; then
            echo -e "      ${GREEN}✓${NC} Работает от пользователя $USERNAME (без sudo)"
        else
            echo -e "      ${RED}✗${NC} Требуется sudo! Перезайдите в систему"
            echo -e "      ${YELLOW}→${NC} Или выполните: newgrp docker"
        fi
    else
        echo -e "  ${YELLOW}○${NC} Docker не установлен"
    fi
    
    # Git
    if command -v git &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Git: $(git --version | cut -d' ' -f3)"
    else
        echo -e "  ${RED}✗${NC} Git не установлен"
        all_ok=false
    fi
    
    echo ""
    echo -e "${CYAN}=== Проверка сервисов ===${NC}"
    
    # Функция проверки сервиса
    check_service() {
        local service=$1
        local name=$2
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "  ${GREEN}●${NC} $name — работает"
        elif systemctl list-unit-files | grep -q "^$service"; then
            echo -e "  ${YELLOW}○${NC} $name — остановлен"
        else
            echo -e "  ${RED}–${NC} $name — не установлен"
        fi
    }
    
    check_service "apache2" "Apache2"
    check_service "nginx" "Nginx"
    check_service "php8.2-fpm" "PHP 8.2 FPM"
    check_service "mariadb" "MariaDB"
    check_service "postgresql" "PostgreSQL"
    check_service "redis-server" "Redis"
    check_service "memcached" "Memcached"
    check_service "mailhog" "MailHog"
    
    echo ""
    echo -e "${CYAN}=== Проверка портов ===${NC}"
    
    check_port() {
        local port=$1
        local name=$2
        if ss -tuln | grep -q ":$port "; then
            echo -e "  ${GREEN}●${NC} Порт $port ($name) — занят"
        else
            echo -e "  ${YELLOW}○${NC} Порт $port ($name) — свободен"
        fi
    }
    
    check_port 80 "HTTP"
    check_port 443 "HTTPS"
    check_port 3306 "MySQL/MariaDB"
    check_port 5432 "PostgreSQL"
    check_port 6379 "Redis"
    check_port 9082 "PHP 8.2 FPM"
    check_port 8025 "MailHog Web"
    
    echo ""
    echo -e "${CYAN}=== Проверка директорий ===${NC}"
    
    if [ -d "$WWW_DIR" ]; then
        echo -e "  ${GREEN}✓${NC} WWW директория: $WWW_DIR"
        echo "      Проекты: $(ls -1 "$WWW_DIR" 2>/dev/null | wc -l)"
    else
        echo -e "  ${RED}✗${NC} WWW директория не создана"
    fi
    
    if [ -d "$HOME_DIR/.ssh" ] && [ -f "$HOME_DIR/.ssh/id_ed25519" ]; then
        echo -e "  ${GREEN}✓${NC} SSH ключ настроен"
    else
        echo -e "  ${YELLOW}○${NC} SSH ключ не создан (запустите: $0 ssh)"
    fi
    
    echo ""
    
    if [ "$all_ok" = true ]; then
        print_success "Все базовые компоненты в порядке!"
    else
        print_warning "Некоторые компоненты отсутствуют"
    fi
    
    print_info "Запуск сервисов: dev start"
    print_info "Статус сервисов: dev status"
}

#===============================================================================
# Функция: Экспорт конфигурации
#===============================================================================
export_config() {
    print_section "Экспорт конфигурации"
    
    local export_dir="$HOME_DIR/dev-env-export"
    local export_file="$export_dir/dev-env-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    
    mkdir -p "$export_dir"
    
    local tmp_dir=$(mktemp -d)
    
    print_info "Сбор конфигурационных файлов..."
    
    # Копирование конфигов
    mkdir -p "$tmp_dir/configs"
    
    # ZSH
    [ -f "$HOME_DIR/.zshrc" ] && cp "$HOME_DIR/.zshrc" "$tmp_dir/configs/"
    [ -f "$HOME_DIR/.p10k.zsh" ] && cp "$HOME_DIR/.p10k.zsh" "$tmp_dir/configs/"
    
    # Git
    [ -f "$HOME_DIR/.gitconfig" ] && cp "$HOME_DIR/.gitconfig" "$tmp_dir/configs/"
    
    # SSH config (не ключи!)
    [ -f "$HOME_DIR/.ssh/config" ] && cp "$HOME_DIR/.ssh/config" "$tmp_dir/configs/ssh_config"
    
    # Список установленных пакетов
    print_info "Сохранение списка пакетов..."
    dpkg --get-selections > "$tmp_dir/packages.list"
    
    # Список PPA репозиториев
    if [ -d /etc/apt/sources.list.d ]; then
        ls /etc/apt/sources.list.d/ > "$tmp_dir/ppa.list" 2>/dev/null || true
    fi
    
    # PHP конфиги
    mkdir -p "$tmp_dir/php"
    for version in 7.3 7.4 8.1 8.2 8.3 8.4; do
        [ -f "/etc/php/$version/cli/php.ini" ] && \
            cp "/etc/php/$version/cli/php.ini" "$tmp_dir/php/php${version}-cli.ini" 2>/dev/null || true
    done
    
    # Nginx конфиги
    mkdir -p "$tmp_dir/nginx"
    [ -d "/etc/nginx/sites-available" ] && \
        cp -r /etc/nginx/sites-available/* "$tmp_dir/nginx/" 2>/dev/null || true
    
    # Apache конфиги
    mkdir -p "$tmp_dir/apache"
    [ -d "/etc/apache2/sites-available" ] && \
        cp /etc/apache2/sites-available/*.conf "$tmp_dir/apache/" 2>/dev/null || true
    
    # Hosts file
    cp /etc/hosts "$tmp_dir/configs/hosts"
    
    # Информация о системе
    cat > "$tmp_dir/system-info.txt" << EOF
Дата экспорта: $(date)
ОС: $(lsb_release -ds 2>/dev/null || echo "Ubuntu")
Версия: $(lsb_release -rs 2>/dev/null || echo "Unknown")
Пользователь: $USERNAME
PHP версия: $(php -v 2>/dev/null | head -1 || echo "Не установлен")
Node версия: $(node -v 2>/dev/null || echo "Не установлен")
Go версия: $(go version 2>/dev/null || echo "Не установлен")
EOF
    
    # Создание архива
    print_info "Создание архива..."
    tar -czf "$export_file" -C "$tmp_dir" .
    
    # Очистка
    rm -rf "$tmp_dir"
    
    print_success "Конфигурация экспортирована: $export_file"
    print_info "Размер: $(du -h "$export_file" | cut -f1)"
    echo ""
    print_info "Для переноса на другую машину:"
    print_info "  1. Скопируйте архив на новую машину"
    print_info "  2. Распакуйте: tar -xzf $(basename "$export_file")"
    print_info "  3. Скопируйте нужные конфиги вручную"
}

#===============================================================================
# Функция: Импорт конфигурации (базовый)
#===============================================================================
import_config() {
    print_section "Импорт конфигурации"
    
    local export_dir="$HOME_DIR/dev-env-export"
    
    if [ ! -d "$export_dir" ]; then
        print_error "Директория экспорта не найдена: $export_dir"
        return 1
    fi
    
    # Поиск последнего архива
    local latest_backup=$(ls -t "$export_dir"/dev-env-backup-*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$latest_backup" ]; then
        print_error "Архивы не найдены в $export_dir"
        return 1
    fi
    
    print_info "Найден архив: $latest_backup"
    read -p "Импортировать конфигурацию? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Отменено"
        return 0
    fi
    
    local tmp_dir=$(mktemp -d)
    tar -xzf "$latest_backup" -C "$tmp_dir"
    
    # Восстановление .zshrc
    if [ -f "$tmp_dir/configs/.zshrc" ]; then
        backup_config "$HOME_DIR/.zshrc"
        cp "$tmp_dir/configs/.zshrc" "$HOME_DIR/.zshrc"
        print_success "Восстановлен .zshrc"
    fi
    
    # Восстановление .gitconfig
    if [ -f "$tmp_dir/configs/.gitconfig" ]; then
        backup_config "$HOME_DIR/.gitconfig"
        cp "$tmp_dir/configs/.gitconfig" "$HOME_DIR/.gitconfig"
        print_success "Восстановлен .gitconfig"
    fi
    
    # Восстановление SSH config
    if [ -f "$tmp_dir/configs/ssh_config" ]; then
        mkdir -p "$HOME_DIR/.ssh"
        backup_config "$HOME_DIR/.ssh/config"
        cp "$tmp_dir/configs/ssh_config" "$HOME_DIR/.ssh/config"
        chmod 600 "$HOME_DIR/.ssh/config"
        print_success "Восстановлен SSH config"
    fi
    
    rm -rf "$tmp_dir"
    
    print_success "Импорт завершён"
    print_warning "Nginx/Apache конфиги нужно восстановить вручную"
}

#===============================================================================
# Функция: Установка Nginx
#===============================================================================
install_nginx() {
    print_section "Установка Nginx"
    
    if is_command_exists nginx; then
        print_warning "Nginx уже установлен: $(nginx -v 2>&1)"
        print_info "Пропускаем установку"
        return 0
    fi
    
    sudo apt install -y nginx
    
    # Резервное копирование перед изменением
    backup_config "/etc/nginx/nginx.conf"
    
    # Настройка nginx.conf
    sudo sed -i "s/www-data/$USERNAME/g" /etc/nginx/nginx.conf
    
    # Добавление client_max_body_size если его нет
    if ! grep -q "client_max_body_size" /etc/nginx/nginx.conf; then
        sudo sed -i '/types_hash_max_size 2048;/a\    client_max_body_size 20M;' /etc/nginx/nginx.conf
    fi
    
    # Отключение автозапуска
    sudo systemctl disable nginx.service
    
    print_success "Nginx установлен"
    nginx -v
    print_info "Для запуска: sudo systemctl start nginx"
}

#===============================================================================
# Функция: Установка Composer
#===============================================================================
install_composer() {
    print_section "Установка Composer"
    
    if is_command_exists composer; then
        print_warning "Composer уже установлен: $(composer --version 2>/dev/null | head -1)"
        print_info "Пропускаем установку"
        return 0
    fi
    
    cd /tmp
    
    # Скачивание и установка Composer
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php
    php -r "unlink('composer-setup.php');"
    sudo mv composer.phar /usr/local/bin/composer
    
    # Добавление глобального Composer bin в PATH
    if ! grep -q "composer/vendor/bin" "$HOME_DIR/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.config/composer/vendor/bin:$PATH"' >> "$HOME_DIR/.zshrc"
    fi
    
    print_success "Composer установлен"
    composer --version
}

#===============================================================================
# Функция: Установка Symfony CLI
#===============================================================================
install_symfony() {
    print_section "Установка Symfony CLI"
    
    if is_command_exists symfony; then
        print_warning "Symfony CLI уже установлен: $(symfony -V 2>/dev/null | head -1)"
        print_info "Пропускаем установку"
        return 0
    fi
    
    wget https://get.symfony.com/cli/installer -O - | bash
    
    # Добавление symfony в PATH
    if [ -d "$HOME_DIR/.symfony5/bin" ]; then
        if ! grep -q ".symfony5/bin" "$HOME_DIR/.zshrc" 2>/dev/null; then
            echo 'export PATH="$HOME/.symfony5/bin:$PATH"' >> "$HOME_DIR/.zshrc"
        fi
    fi
    
    print_success "Symfony CLI установлен"
}

#===============================================================================
# Функция: Установка NVM (Node Version Manager)
#===============================================================================
install_nvm() {
    print_section "Установка NVM"
    
    if [ -d "$HOME_DIR/.nvm" ]; then
        print_warning "NVM уже установлен"
        print_info "Пропускаем установку"
        return 0
    fi
    
    # Установка NVM
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
    
    print_success "NVM установлен"
    
    add_recommendation "Установите Node.js: nvm install --lts"
}

#===============================================================================
# Функция: Установка Laravel
#===============================================================================
install_laravel() {
    print_section "Установка Laravel Installer"
    
    # Проверка Composer
    if ! is_command_exists composer; then
        print_error "Composer не установлен. Сначала установите Composer."
        return 1
    fi
    
    if is_command_exists laravel; then
        print_warning "Laravel Installer уже установлен"
        print_info "Пропускаем установку"
        return 0
    fi
    
    composer global require laravel/installer
    
    print_success "Laravel Installer установлен"
    print_info "Создание проекта: laravel new project-name"
}

#===============================================================================
# Функция: Установка Docker
#===============================================================================
install_docker() {
    print_section "Установка Docker"
    
    if is_command_exists docker; then
        print_warning "Docker уже установлен: $(docker --version)"
        print_info "Пропускаем установку"
        return 0
    fi
    
    # Скачивание и установка Docker
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sudo sh /tmp/get-docker.sh
    rm /tmp/get-docker.sh
    
    # Добавление текущего пользователя в группу docker
    sudo usermod -aG docker $USERNAME
    
    print_success "Docker установлен"
    
    # Проверка группы
    if groups | grep -q docker; then
        print_success "Пользователь $USERNAME уже в группе docker"
    else
        print_warning "Пользователь $USERNAME добавлен в группу docker"
        print_info "Для применения изменений:"
        print_info "  1. Перезайдите в систему (logout/login)"
        print_info "  2. Или выполните: newgrp docker"
        print_info ""
        print_info "Проверка: docker ps (должно работать без sudo)"
    fi
    
    add_recommendation "Перезайдите в систему для работы Docker без sudo"
}

#===============================================================================
# Функция: Установка приложений (VS Code, Chrome, Cursor, etc)
#===============================================================================
install_apps() {
    print_section "Установка приложений"
    
    cd /tmp
    
    # --- VS Code ---
    print_info "Установка VS Code..."
    if ! is_command_exists code; then
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        rm -f packages.microsoft.gpg
        sudo apt update
        sudo apt install -y code
        print_success "VS Code установлен"
    else
        print_warning "VS Code уже установлен"
    fi
    
    # --- Google Chrome ---
    print_info "Установка Google Chrome..."
    if ! is_command_exists google-chrome; then
        print_info "Скачивание Google Chrome .deb..."
        wget --progress=bar:force "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" -O chrome.deb 2>&1 || true
        if [ -f chrome.deb ] && [ -s chrome.deb ]; then
            sudo apt install -y ./chrome.deb
            rm -f chrome.deb
            print_success "Google Chrome установлен"
        else
            print_warning "Не удалось скачать Google Chrome"
            FAILED_DOWNLOADS+=("Google Chrome — https://www.google.com/chrome/")
        fi
    else
        print_warning "Google Chrome уже установлен"
    fi
    
    # --- Cursor ---
    print_info "Установка Cursor..."
    if ! is_command_exists cursor && [ ! -f /usr/bin/cursor ]; then
        # Скачивание .deb пакета Cursor
        local cursor_url="https://downloader.cursor.sh/linux/deb/x64"
        print_info "Скачивание Cursor .deb (это может занять несколько минут)..."
        wget --progress=bar:force "$cursor_url" -O cursor.deb 2>&1 || true
        if [ -f cursor.deb ] && [ -s cursor.deb ]; then
            sudo dpkg -i cursor.deb || sudo apt install -f -y
            rm -f cursor.deb
            print_success "Cursor установлен"
        else
            print_warning "Не удалось скачать Cursor"
            FAILED_DOWNLOADS+=("Cursor — https://cursor.com/downloads")
        fi
    else
        print_warning "Cursor уже установлен"
    fi
    
    # --- Obsidian ---
    print_info "Установка Obsidian..."
    if ! is_command_exists obsidian && ! dpkg -l | grep -q obsidian; then
        # Получаем последнюю версию с GitHub
        local obsidian_version="1.5.12"
        print_info "Скачивание Obsidian .deb..."
        wget --progress=bar:force "https://github.com/obsidianmd/obsidian-releases/releases/download/v${obsidian_version}/obsidian_${obsidian_version}_amd64.deb" -O obsidian.deb 2>&1 || true
        if [ -f obsidian.deb ] && [ -s obsidian.deb ]; then
            sudo apt install -y ./obsidian.deb
            rm -f obsidian.deb
            print_success "Obsidian установлен"
        else
            print_warning "Не удалось скачать Obsidian"
            FAILED_DOWNLOADS+=("Obsidian — https://obsidian.md/download")
        fi
    else
        print_warning "Obsidian уже установлен"
    fi
    
    # --- Thunderbird ---
    print_info "Установка Thunderbird..."
    if ! is_command_exists thunderbird; then
        sudo apt install -y thunderbird
        print_success "Thunderbird установлен"
    else
        print_warning "Thunderbird уже установлен"
    fi
    
    # --- FileZilla ---
    print_info "Установка FileZilla..."
    if ! is_command_exists filezilla; then
        sudo apt install -y filezilla
        print_success "FileZilla установлен"
    else
        print_warning "FileZilla уже установлен"
    fi
    
    # --- PhpStorm ---
    print_info "Установка PhpStorm..."
    if [ ! -d "/opt/phpstorm" ]; then
        # Скачиваем последнюю версию PhpStorm
        local phpstorm_url="https://download.jetbrains.com/webide/PhpStorm-2024.3.1.1.tar.gz"
        print_info "Скачивание PhpStorm (это может занять время)..."
        wget --progress=bar:force "$phpstorm_url" -O phpstorm.tar.gz 2>&1 || true
        if [ -f phpstorm.tar.gz ] && [ -s phpstorm.tar.gz ]; then
            # Распаковка в /opt
            sudo tar -xzf phpstorm.tar.gz -C /opt
            # Переименование директории
            sudo mv /opt/PhpStorm-* /opt/phpstorm
            sudo chown -R root:root /opt/phpstorm
            rm -f phpstorm.tar.gz
            
            # Создание символической ссылки
            sudo ln -sf /opt/phpstorm/bin/phpstorm.sh /usr/local/bin/phpstorm
            
            # Создание .desktop файла
            sudo tee /usr/share/applications/phpstorm.desktop > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=PhpStorm
Comment=PHP IDE
Exec=/opt/phpstorm/bin/phpstorm.sh %f
Icon=/opt/phpstorm/bin/phpstorm.png
Terminal=false
Categories=Development;IDE;
StartupWMClass=jetbrains-phpstorm
EOF
            sudo update-desktop-database
            
            print_success "PhpStorm установлен в /opt/phpstorm"
            print_info "Запуск: phpstorm или через меню приложений"
            
            add_recommendation "Для активации PhpStorm используйте ja-netfilter (если есть)"
        else
            print_warning "Не удалось скачать PhpStorm"
            FAILED_DOWNLOADS+=("PhpStorm — https://www.jetbrains.com/phpstorm/download/")
        fi
    else
        print_warning "PhpStorm уже установлен в /opt/phpstorm"
    fi
    
    cd - > /dev/null
    
    print_success "Приложения установлены"
}

#===============================================================================
# Функция: Установка дополнительного софта
#===============================================================================
install_extras() {
    print_section "Установка дополнительного софта"
    
    
    # Papirus icon theme
    print_info "Установка Papirus icon theme..."
    sudo add-apt-repository -y ppa:papirus/papirus
    sudo apt update
    sudo apt install -y papirus-icon-theme
    
    print_success "Дополнительный софт установлен"
}

#===============================================================================
# Функция: Создание рабочих директорий
#===============================================================================
create_directories() {
    print_section "Создание рабочих директорий"
    
    mkdir -p "$WWW_DIR"
    mkdir -p "$BACKUP_DIR"
    
    print_success "Директория $WWW_DIR создана"
    print_success "Директория $BACKUP_DIR создана"
}

#===============================================================================
# Функция: Настройка Git
#===============================================================================
configure_git() {
    print_section "Настройка Git"
    
    # Использование параметров собранных в начале или запрос новых
    local git_name="$USER_GIT_NAME"
    local git_email="$USER_GIT_EMAIL"
    
    # Если параметры не были собраны, запросить
    if [ -z "$git_name" ]; then
        local current_name=$(git config --global user.name 2>/dev/null || echo "")
        if [ -z "$current_name" ]; then
            read -p "Введите ваше имя для Git: " git_name
        else
            git_name="$current_name"
            print_info "Git user.name уже настроен: $current_name"
        fi
    fi
    
    if [ -z "$git_email" ]; then
        local current_email=$(git config --global user.email 2>/dev/null || echo "")
        if [ -z "$current_email" ]; then
            read -p "Введите ваш email для Git: " git_email
        else
            git_email="$current_email"
            print_info "Git user.email уже настроен: $current_email"
        fi
    fi
    
    # Применение настроек
    if [ -n "$git_name" ]; then
        git config --global user.name "$git_name"
        print_success "Git user.name: $git_name"
    fi
    
    if [ -n "$git_email" ]; then
        git config --global user.email "$git_email"
        print_success "Git user.email: $git_email"
    fi
    
    # Полезные алиасы
    git config --global alias.st "status"
    git config --global alias.co "checkout"
    git config --global alias.br "branch"
    git config --global alias.ci "commit"
    git config --global alias.unstage "reset HEAD --"
    git config --global alias.last "log -1 HEAD"
    git config --global alias.lg "log --oneline --graph --decorate --all"
    git config --global alias.df "diff"
    git config --global alias.dfs "diff --staged"
    
    # Настройки
    git config --global init.defaultBranch "main"
    git config --global core.autocrlf "input"
    git config --global pull.rebase "false"
    git config --global push.autoSetupRemote "true"
    
    print_success "Git алиасы настроены: st, co, br, ci, lg, df, dfs"
    
    add_recommendation "Используйте git lg для красивого лога коммитов"
}

#===============================================================================
# Функция: Генерация SSH ключей
#===============================================================================
generate_ssh_keys() {
    print_section "Генерация SSH ключей"
    
    local ssh_dir="$HOME_DIR/.ssh"
    local ssh_key="$ssh_dir/id_ed25519"
    
    # Проверка существующего ключа
    if [ -f "$ssh_key" ]; then
        # Если параметр собран в начале — использовать его
        if [ "$GENERATE_NEW_SSH" = false ]; then
            print_info "Используется существующий SSH ключ"
            add_recommendation "Добавьте SSH ключ в GitHub/GitLab: cat ~/.ssh/id_ed25519.pub"
            return 0
        elif [ "$GENERATE_NEW_SSH" != true ]; then
            # Если не было сбора параметров — спросить
            print_warning "SSH ключ уже существует: $ssh_key"
            read -p "Создать новый ключ? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Используется существующий ключ"
                add_recommendation "Добавьте SSH ключ в GitHub/GitLab: cat ~/.ssh/id_ed25519.pub"
                return 0
            fi
        fi
        # Бэкап существующего ключа
        backup_config "$ssh_key"
        backup_config "$ssh_key.pub"
    fi
    
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Получение email для ключа (из собранных параметров или git config)
    local email="$USER_GIT_EMAIL"
    if [ -z "$email" ]; then
        email=$(git config --global user.email 2>/dev/null || echo "")
    fi
    if [ -z "$email" ]; then
        read -p "Введите email для SSH ключа: " email
    fi
    
    # Генерация ключа ED25519 (более безопасный чем RSA)
    ssh-keygen -t ed25519 -C "$email" -f "$ssh_key" -N ""
    
    # Запуск ssh-agent и добавление ключа
    eval "$(ssh-agent -s)" &>/dev/null
    ssh-add "$ssh_key" 2>/dev/null
    
    # Настройка SSH config
    local ssh_config="$ssh_dir/config"
    if [ ! -f "$ssh_config" ]; then
        cat > "$ssh_config" << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes

Host bitbucket.org
    HostName bitbucket.org
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes

Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
EOF
        chmod 600 "$ssh_config"
        print_success "SSH config создан"
    fi
    
    print_success "SSH ключ сгенерирован"
    
    # Копирование в буфер обмена если есть xclip
    if command -v xclip &>/dev/null; then
        cat "$ssh_key.pub" | xclip -selection clipboard 2>/dev/null
        print_info "Ключ скопирован в буфер обмена"
    fi
    
    add_recommendation "Добавьте SSH ключ в GitHub/GitLab/Bitbucket"
}

#===============================================================================
# Функция: Создание systemd сервиса для MailHog
#===============================================================================
create_mailhog_service() {
    print_section "Создание systemd сервиса для MailHog"
    
    # Проверка что MailHog установлен
    if [ ! -f "$HOME_DIR/go/bin/MailHog" ]; then
        print_error "MailHog не установлен. Сначала выполните: $0 mailhog"
        return 1
    fi
    
    local service_file="/etc/systemd/system/mailhog.service"
    
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=MailHog Email Catcher
After=network.target

[Service]
Type=simple
User=$USERNAME
ExecStart=$HOME_DIR/go/bin/MailHog
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable mailhog.service
    
    print_success "Сервис MailHog создан и включён"
    print_info "Управление:"
    print_info "  sudo systemctl start mailhog   — запуск"
    print_info "  sudo systemctl stop mailhog    — остановка"
    print_info "  sudo systemctl status mailhog  — статус"
}

#===============================================================================
# Функция: Создание скрипта управления сервисами (dev)
#===============================================================================
create_dev_script() {
    print_section "Создание скрипта управления сервисами"
    
    local dev_script="/usr/local/bin/dev"
    
    if [ -f "$dev_script" ]; then
        print_warning "Скрипт 'dev' уже существует"
        print_info "Обновляем..."
    fi
    
    sudo tee "$dev_script" > /dev/null << 'DEVSCRIPT'
#!/bin/bash

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Сервисы
WEB_SERVICES="apache2 nginx"
DB_SERVICES="mariadb postgresql"
CACHE_SERVICES="redis-server memcached"
# Динамически определяем установленные PHP-FPM сервисы
PHP_SERVICES=""
for v in 7.3 7.4 8.1 8.2 8.3 8.4; do
    if systemctl list-unit-files "php${v}-fpm.service" 2>/dev/null | grep -q "php${v}-fpm"; then
        PHP_SERVICES="$PHP_SERVICES php${v}-fpm"
    fi
done
PHP_SERVICES=$(echo "$PHP_SERVICES" | xargs)  # trim whitespace
OTHER_SERVICES="mailhog"

ALL_SERVICES="$WEB_SERVICES $DB_SERVICES $CACHE_SERVICES $PHP_SERVICES $OTHER_SERVICES"

print_status() {
    local service=$1
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "  ${GREEN}●${NC} $service ${GREEN}(active)${NC}"
    else
        echo -e "  ${RED}○${NC} $service ${RED}(inactive)${NC}"
    fi
}

start_services() {
    local services="${1:-$ALL_SERVICES}"
    echo -e "${BLUE}Запуск сервисов...${NC}"
    for service in $services; do
        if systemctl list-unit-files | grep -q "^$service"; then
            sudo systemctl start "$service" 2>/dev/null && \
                echo -e "  ${GREEN}✓${NC} $service запущен" || \
                echo -e "  ${YELLOW}!${NC} $service не удалось запустить"
        fi
    done
}

stop_services() {
    local services="${1:-$ALL_SERVICES}"
    echo -e "${BLUE}Остановка сервисов...${NC}"
    for service in $services; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            sudo systemctl stop "$service" 2>/dev/null && \
                echo -e "  ${GREEN}✓${NC} $service остановлен" || \
                echo -e "  ${YELLOW}!${NC} $service не удалось остановить"
        fi
    done
}

restart_services() {
    local services="${1:-$ALL_SERVICES}"
    echo -e "${BLUE}Перезапуск сервисов...${NC}"
    for service in $services; do
        if systemctl list-unit-files | grep -q "^$service"; then
            sudo systemctl restart "$service" 2>/dev/null && \
                echo -e "  ${GREEN}✓${NC} $service перезапущен" || \
                echo -e "  ${YELLOW}!${NC} $service не удалось перезапустить"
        fi
    done
}

status_services() {
    echo -e "${BLUE}=== Статус сервисов ===${NC}"
    echo ""
    echo -e "${YELLOW}Web серверы:${NC}"
    for s in $WEB_SERVICES; do print_status "$s"; done
    echo ""
    echo -e "${YELLOW}Базы данных:${NC}"
    for s in $DB_SERVICES; do print_status "$s"; done
    echo ""
    echo -e "${YELLOW}Кэш:${NC}"
    for s in $CACHE_SERVICES; do print_status "$s"; done
    echo ""
    echo -e "${YELLOW}PHP-FPM:${NC}"
    for s in $PHP_SERVICES; do print_status "$s"; done
    echo ""
    echo -e "${YELLOW}Другие:${NC}"
    for s in $OTHER_SERVICES; do print_status "$s"; done
}

show_help() {
    echo "Управление dev-сервисами"
    echo ""
    echo "Использование: dev <команда> [сервисы]"
    echo ""
    echo "Команды:"
    echo "  start [сервисы]   - Запустить сервисы (все по умолчанию)"
    echo "  stop [сервисы]    - Остановить сервисы"
    echo "  restart [сервисы] - Перезапустить сервисы"
    echo "  status            - Показать статус всех сервисов"
    echo "  web               - Запустить только web (apache2/nginx + php-fpm)"
    echo "  db                - Запустить только БД (mariadb + postgresql)"
    echo "  cache             - Запустить только кэш (redis + memcached)"
    echo "  php <версия>      - Переключить версию PHP CLI"
    echo ""
    echo "Примеры:"
    echo "  dev start         - Запустить все сервисы"
    echo "  dev stop nginx    - Остановить только nginx"
    echo "  dev web           - Запустить web-стек"
    echo "  dev cache         - Запустить redis и memcached"
    echo "  dev php 8.2       - Переключить PHP CLI на 8.2"
}

switch_php() {
    local version="$1"
    if [ -z "$version" ]; then
        echo -e "${YELLOW}Текущая версия PHP CLI:${NC}"
        php -v | head -1
        echo ""
        echo "Доступные версии:"
        sudo update-alternatives --list php 2>/dev/null
        echo ""
        echo "Использование: dev php <версия>"
        return
    fi
    
    local php_path="/usr/bin/php$version"
    if [ -f "$php_path" ]; then
        sudo update-alternatives --set php "$php_path"
        echo -e "${GREEN}PHP CLI переключён на версию $version${NC}"
        php -v | head -1
    else
        echo -e "${RED}PHP $version не установлен${NC}"
    fi
}

case "$1" in
    start)
        shift
        start_services "$*"
        ;;
    stop)
        shift
        stop_services "$*"
        ;;
    restart)
        shift
        restart_services "$*"
        ;;
    status|st)
        status_services
        ;;
    web)
        start_services "$WEB_SERVICES $PHP_SERVICES"
        ;;
    db)
        start_services "$DB_SERVICES"
        ;;
    cache)
        start_services "$CACHE_SERVICES"
        ;;
    php)
        switch_php "$2"
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo -e "${RED}Неизвестная команда: $1${NC}"
        show_help
        exit 1
        ;;
esac
DEVSCRIPT
    
    sudo chmod +x "$dev_script"
    
    print_success "Скрипт 'dev' установлен в /usr/local/bin/dev"
    print_info "Использование:"
    print_info "  dev start   — запустить все сервисы"
    print_info "  dev stop    — остановить все сервисы"
    print_info "  dev status  — показать статус"
    print_info "  dev web     — запустить только web-стек"
    print_info "  dev php 8.2 — переключить версию PHP"
}

#===============================================================================
# Функция: Создание скрипта для нового проекта
#===============================================================================
create_new_project_script() {
    print_section "Создание скрипта для новых проектов"
    
    local script_path="/usr/local/bin/new-project"
    
    if [ -f "$script_path" ]; then
        print_warning "Скрипт 'new-project' уже существует"
        print_info "Обновляем..."
    fi
    
    sudo tee "$script_path" > /dev/null << 'PROJECTSCRIPT'
#!/bin/bash

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

USERNAME=$(whoami)
HOME_DIR="/home/$USERNAME"
WWW_DIR="$HOME_DIR/www"

show_help() {
    echo "Создание нового проекта с настройкой окружения"
    echo ""
    echo "Использование: new-project <имя> [опции]"
    echo ""
    echo "Опции:"
    echo "  --server=apache|nginx   Веб-сервер (по умолчанию: nginx)"
    echo "  --php=8.1|8.2|8.3|8.4   Версия PHP (по умолчанию: 8.2)"
    echo "  --type=laravel|symfony|plain  Тип проекта (по умолчанию: plain)"
    echo "  --no-ssl                Не создавать SSL сертификат"
    echo ""
    echo "Примеры:"
    echo "  new-project mysite.test"
    echo "  new-project blog.test --server=apache --php=8.3"
    echo "  new-project api.test --type=laravel"
}

# Парсинг аргументов
PROJECT_NAME=""
SERVER="nginx"
PHP_VERSION="8.2"
PROJECT_TYPE="plain"
CREATE_SSL=true

while [[ $# -gt 0 ]]; do
    case $1 in
        --server=*)
            SERVER="${1#*=}"
            shift
            ;;
        --php=*)
            PHP_VERSION="${1#*=}"
            shift
            ;;
        --type=*)
            PROJECT_TYPE="${1#*=}"
            shift
            ;;
        --no-ssl)
            CREATE_SSL=false
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        -*)
            echo -e "${RED}Неизвестная опция: $1${NC}"
            show_help
            exit 1
            ;;
        *)
            PROJECT_NAME="$1"
            shift
            ;;
    esac
done

if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}Ошибка: не указано имя проекта${NC}"
    show_help
    exit 1
fi

# Убираем .test если пользователь его не добавил
if [[ ! "$PROJECT_NAME" == *.* ]]; then
    PROJECT_NAME="${PROJECT_NAME}.test"
fi

PROJECT_DIR="$WWW_DIR/$PROJECT_NAME"
PHP_PORT="90${PHP_VERSION//./}"

echo -e "${BLUE}=== Создание проекта: $PROJECT_NAME ===${NC}"
echo -e "  Директория: $PROJECT_DIR"
echo -e "  Сервер: $SERVER"
echo -e "  PHP: $PHP_VERSION (порт $PHP_PORT)"
echo -e "  Тип: $PROJECT_TYPE"
echo -e "  SSL: $CREATE_SSL"
echo ""

# Создание директории проекта
mkdir -p "$PROJECT_DIR/public"
echo "<?php phpinfo();" > "$PROJECT_DIR/public/index.php"
echo -e "${GREEN}✓${NC} Директория создана"

# Создание SSL сертификата
if [ "$CREATE_SSL" = true ]; then
    cd "$PROJECT_DIR"
    if command -v mkcert &>/dev/null; then
        mkcert "$PROJECT_NAME" "*.$PROJECT_NAME" localhost 127.0.0.1 ::1
        sudo cp "${PROJECT_NAME}+4.pem" "/etc/ssl/certs/${PROJECT_NAME}.pem"
        sudo cp "${PROJECT_NAME}+4-key.pem" "/etc/ssl/private/${PROJECT_NAME}-key.pem"
        sudo chmod 644 "/etc/ssl/certs/${PROJECT_NAME}.pem"
        sudo chmod 644 "/etc/ssl/private/${PROJECT_NAME}-key.pem"
        rm -f "${PROJECT_NAME}+4.pem" "${PROJECT_NAME}+4-key.pem"
        echo -e "${GREEN}✓${NC} SSL сертификат создан"
    else
        echo -e "${YELLOW}!${NC} mkcert не установлен, SSL пропущен"
        CREATE_SSL=false
    fi
fi

# Создание конфига для Nginx
if [ "$SERVER" = "nginx" ]; then
    CONF_FILE="/etc/nginx/sites-available/$PROJECT_NAME"
    
    if [ "$CREATE_SSL" = true ]; then
        sudo tee "$CONF_FILE" > /dev/null << NGINXCONF
server {
    listen 80;
    listen [::]:80;
    server_name $PROJECT_NAME *.$PROJECT_NAME;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    root $PROJECT_DIR/public;
    index index.php index.html;
    server_name $PROJECT_NAME *.$PROJECT_NAME;

    ssl_certificate      /etc/ssl/certs/${PROJECT_NAME}.pem;
    ssl_certificate_key  /etc/ssl/private/${PROJECT_NAME}-key.pem;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass 127.0.0.1:$PHP_PORT;
    }
}
NGINXCONF
    else
        sudo tee "$CONF_FILE" > /dev/null << NGINXCONF
server {
    listen 80;
    listen [::]:80;
    
    root $PROJECT_DIR/public;
    index index.php index.html;
    server_name $PROJECT_NAME *.$PROJECT_NAME;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass 127.0.0.1:$PHP_PORT;
    }
}
NGINXCONF
    fi
    
    sudo ln -sf "$CONF_FILE" "/etc/nginx/sites-enabled/$PROJECT_NAME"
    sudo nginx -t && sudo systemctl reload nginx
    echo -e "${GREEN}✓${NC} Nginx конфиг создан и активирован"
fi

# Создание конфига для Apache
if [ "$SERVER" = "apache" ]; then
    CONF_FILE="/etc/apache2/sites-available/$PROJECT_NAME.conf"
    
    sudo tee "$CONF_FILE" > /dev/null << APACHECONF
Define ROOT "$PROJECT_DIR/public"
Define SITE "$PROJECT_NAME"

<VirtualHost *:80>
    DocumentRoot "\${ROOT}"
    ServerName \${SITE}
    ServerAlias *.\${SITE}
    <Directory "\${ROOT}">
        AllowOverride All
        Require all granted
        Options Indexes FollowSymLinks
        DirectoryIndex index.php
        <IfModule mpm_itk_module>
            AssignUserId $USERNAME $USERNAME
        </IfModule>
    </Directory>
</VirtualHost>
APACHECONF

    if [ "$CREATE_SSL" = true ]; then
        sudo tee -a "$CONF_FILE" > /dev/null << APACHESSL

<VirtualHost *:443>
    DocumentRoot "\${ROOT}"
    ServerName \${SITE}
    ServerAlias *.\${SITE}
    <Directory "\${ROOT}">
        AllowOverride All
        Require all granted
        Options Indexes FollowSymLinks
        DirectoryIndex index.php
        <IfModule mpm_itk_module>
            AssignUserId $USERNAME $USERNAME
        </IfModule>
    </Directory>
    SSLEngine on
    SSLCertificateFile      "/etc/ssl/certs/${PROJECT_NAME}.pem"
    SSLCertificateKeyFile   "/etc/ssl/private/${PROJECT_NAME}-key.pem"
</VirtualHost>
APACHESSL
    fi
    
    sudo a2ensite "$PROJECT_NAME.conf"
    sudo systemctl reload apache2
    echo -e "${GREEN}✓${NC} Apache конфиг создан и активирован"
fi

# Добавление в /etc/hosts
if ! grep -q "$PROJECT_NAME" /etc/hosts; then
    echo "127.0.0.1 $PROJECT_NAME www.$PROJECT_NAME" | sudo tee -a /etc/hosts > /dev/null
    echo -e "${GREEN}✓${NC} Добавлено в /etc/hosts"
fi

# Создание проекта по типу
case "$PROJECT_TYPE" in
    laravel)
        if command -v laravel &>/dev/null; then
            cd "$WWW_DIR"
            rm -rf "$PROJECT_DIR"
            laravel new "$PROJECT_NAME"
            echo -e "${GREEN}✓${NC} Laravel проект создан"
        else
            echo -e "${YELLOW}!${NC} Laravel Installer не установлен"
        fi
        ;;
    symfony)
        if command -v symfony &>/dev/null; then
            cd "$WWW_DIR"
            rm -rf "$PROJECT_DIR"
            symfony new "$PROJECT_NAME" --webapp
            echo -e "${GREEN}✓${NC} Symfony проект создан"
        else
            echo -e "${YELLOW}!${NC} Symfony CLI не установлен"
        fi
        ;;
esac

echo ""
echo -e "${GREEN}=== Проект создан успешно! ===${NC}"
echo ""
if [ "$CREATE_SSL" = true ]; then
    echo -e "  URL: ${BLUE}https://$PROJECT_NAME${NC}"
else
    echo -e "  URL: ${BLUE}http://$PROJECT_NAME${NC}"
fi
echo -e "  Директория: $PROJECT_DIR"
echo ""
echo -e "${YELLOW}Не забудьте запустить сервисы:${NC} dev start"
PROJECTSCRIPT
    
    sudo chmod +x "$script_path"
    
    print_success "Скрипт 'new-project' установлен"
    print_info "Использование:"
    print_info "  new-project mysite.test"
    print_info "  new-project blog.test --php=8.3 --server=apache"
    print_info "  new-project api.test --type=laravel"
}

#===============================================================================
# Функция: Создание шаблона Apache VirtualHost
#===============================================================================
#===============================================================================
# Функция: Создание тестовых хостов (Apache + Nginx с PHP 8.4)
#===============================================================================
create_test_hosts() {
    print_section "Создание тестовых хостов"
    
    local apache_host="test-apache.test"
    local nginx_host="test-nginx.test"
    local php_port="9084"  # PHP 8.4
    
    # Создание директорий
    mkdir -p "$WWW_DIR/$apache_host/public"
    mkdir -p "$WWW_DIR/$nginx_host/public"
    
    # Создание тестовых index.php
    cat > "$WWW_DIR/$apache_host/public/index.php" << 'PHPCODE'
<?php
echo "<h1>Apache + PHP " . phpversion() . "</h1>";
echo "<p>Server: " . $_SERVER['SERVER_SOFTWARE'] . "</p>";
echo "<p>Document Root: " . $_SERVER['DOCUMENT_ROOT'] . "</p>";
echo "<hr>";
phpinfo();
PHPCODE

    cat > "$WWW_DIR/$nginx_host/public/index.php" << 'PHPCODE'
<?php
echo "<h1>Nginx + PHP " . phpversion() . "</h1>";
echo "<p>Server: " . $_SERVER['SERVER_SOFTWARE'] . "</p>";
echo "<p>Document Root: " . $_SERVER['DOCUMENT_ROOT'] . "</p>";
echo "<hr>";
phpinfo();
PHPCODE

    print_success "Директории созданы"
    
    # --- Создание SSL сертификатов ---
    if is_command_exists mkcert; then
        print_info "Создание SSL сертификатов..."
        cd /tmp
        
        # Для Apache
        mkcert "$apache_host" "*.$apache_host" localhost 127.0.0.1 ::1 2>/dev/null
        sudo cp "${apache_host}+4.pem" "/etc/ssl/certs/${apache_host}.pem"
        sudo cp "${apache_host}+4-key.pem" "/etc/ssl/private/${apache_host}-key.pem"
        sudo chmod 644 "/etc/ssl/certs/${apache_host}.pem"
        sudo chmod 644 "/etc/ssl/private/${apache_host}-key.pem"
        rm -f "${apache_host}+4.pem" "${apache_host}+4-key.pem"
        
        # Для Nginx
        mkcert "$nginx_host" "*.$nginx_host" localhost 127.0.0.1 ::1 2>/dev/null
        sudo cp "${nginx_host}+4.pem" "/etc/ssl/certs/${nginx_host}.pem"
        sudo cp "${nginx_host}+4-key.pem" "/etc/ssl/private/${nginx_host}-key.pem"
        sudo chmod 644 "/etc/ssl/certs/${nginx_host}.pem"
        sudo chmod 644 "/etc/ssl/private/${nginx_host}-key.pem"
        rm -f "${nginx_host}+4.pem" "${nginx_host}+4-key.pem"
        
        cd - > /dev/null
        print_success "SSL сертификаты созданы"
    else
        print_warning "mkcert не установлен — SSL сертификаты не созданы"
    fi
    
    # --- Конфиг Apache ---
    if [ -d "/etc/apache2/sites-available" ]; then
        print_info "Создание конфига Apache для $apache_host..."
        
        sudo tee "/etc/apache2/sites-available/${apache_host}.conf" > /dev/null << APACHECONF
Define ROOT "$WWW_DIR/$apache_host/public"
Define SITE "$apache_host"

# Apache использует порты 8080 и 8443 (Nginx на 80 и 443)

<VirtualHost *:8080>
    DocumentRoot "\${ROOT}"
    ServerName \${SITE}
    ServerAlias *.\${SITE}
    <Directory "\${ROOT}">
        AllowOverride All
        Require all granted
        Options Indexes FollowSymLinks
        DirectoryIndex index.php
        <IfModule mpm_itk_module>
            AssignUserId $USERNAME $USERNAME
        </IfModule>
    </Directory>
    
    # Использование PHP 8.4 через FPM
    <FilesMatch \.php$>
        SetHandler "proxy:fcgi://127.0.0.1:$php_port"
    </FilesMatch>
</VirtualHost>

<VirtualHost *:8443>
    DocumentRoot "\${ROOT}"
    ServerName \${SITE}
    ServerAlias *.\${SITE}
    <Directory "\${ROOT}">
        AllowOverride All
        Require all granted
        Options Indexes FollowSymLinks
        DirectoryIndex index.php
        <IfModule mpm_itk_module>
            AssignUserId $USERNAME $USERNAME
        </IfModule>
    </Directory>
    
    # Использование PHP 8.4 через FPM
    <FilesMatch \.php$>
        SetHandler "proxy:fcgi://127.0.0.1:$php_port"
    </FilesMatch>
    
    SSLEngine on
    SSLCertificateFile      "/etc/ssl/certs/${apache_host}.pem"
    SSLCertificateKeyFile   "/etc/ssl/private/${apache_host}-key.pem"
</VirtualHost>
APACHECONF
        
        # Включение необходимых модулей Apache
        sudo a2enmod proxy_fcgi 2>/dev/null || true
        sudo a2ensite "${apache_host}.conf" 2>/dev/null
        
        print_success "Apache конфиг создан: $apache_host"
    else
        print_warning "Apache не установлен"
    fi
    
    # --- Конфиг Nginx ---
    if [ -d "/etc/nginx/sites-available" ]; then
        print_info "Создание конфига Nginx для $nginx_host..."
        
        sudo tee "/etc/nginx/sites-available/${nginx_host}" > /dev/null << NGINXCONF
server {
    listen 80;
    listen [::]:80;
    server_name $nginx_host *.$nginx_host;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    root $WWW_DIR/$nginx_host/public;
    index index.php index.html;

    server_name $nginx_host *.$nginx_host;

    ssl_certificate      /etc/ssl/certs/${nginx_host}.pem;
    ssl_certificate_key  /etc/ssl/private/${nginx_host}-key.pem;

    ssl_session_timeout  1d;
    ssl_session_cache    shared:SSL:50m;
    ssl_protocols        TLSv1.2 TLSv1.3;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass 127.0.0.1:$php_port;
    }

    location ~ /\.ht {
        deny all;
    }
}
NGINXCONF
        
        sudo ln -sf "/etc/nginx/sites-available/${nginx_host}" "/etc/nginx/sites-enabled/${nginx_host}"
        
        print_success "Nginx конфиг создан: $nginx_host"
    else
        print_warning "Nginx не установлен"
    fi
    
    # --- Добавление в /etc/hosts ---
    print_info "Добавление в /etc/hosts..."
    
    if ! grep -q "$apache_host" /etc/hosts; then
        echo "127.0.0.1 $apache_host www.$apache_host" | sudo tee -a /etc/hosts > /dev/null
        print_success "Добавлен: $apache_host"
    fi
    
    if ! grep -q "$nginx_host" /etc/hosts; then
        echo "127.0.0.1 $nginx_host www.$nginx_host" | sudo tee -a /etc/hosts > /dev/null
        print_success "Добавлен: $nginx_host"
    fi
    
    # --- Перезапуск сервисов ---
    print_info "Проверка конфигурации..."
    
    if is_command_exists apache2; then
        sudo apache2ctl configtest 2>/dev/null && print_success "Apache конфиг OK" || print_warning "Проверьте конфиг Apache"
    fi
    
    if is_command_exists nginx; then
        sudo nginx -t 2>/dev/null && print_success "Nginx конфиг OK" || print_warning "Проверьте конфиг Nginx"
    fi
    
    # --- Итоговая информация ---
    print_section "Тестовые хосты созданы"
    
    echo -e "${GREEN}Apache + PHP 8.4 (порты 8080/8443):${NC}"
    echo -e "  HTTP:      ${CYAN}http://$apache_host:8080${NC}"
    echo -e "  HTTPS:     ${CYAN}https://$apache_host:8443${NC}"
    echo -e "  Директория: $WWW_DIR/$apache_host/public"
    echo ""
    echo -e "${GREEN}Nginx + PHP 8.4 (порты 80/443):${NC}"
    echo -e "  HTTP:      ${CYAN}http://$nginx_host${NC}"
    echo -e "  HTTPS:     ${CYAN}https://$nginx_host${NC}"
    echo -e "  Директория: $WWW_DIR/$nginx_host/public"
    echo ""
    echo -e "${YELLOW}Apache и Nginx могут работать одновременно!${NC}"
    echo ""
    echo -e "${YELLOW}Для запуска:${NC}"
    echo -e "  ${GREEN}dev start${NC}"
    echo ""
    echo -e "${YELLOW}Или по отдельности:${NC}"
    echo -e "  ${GREEN}sudo systemctl start apache2 php8.4-fpm${NC}"
    echo -e "  ${GREEN}sudo systemctl start nginx php8.4-fpm${NC}"
    
    add_recommendation "Apache: http://$apache_host:8080 | Nginx: https://$nginx_host"
}

create_apache_vhost_template() {
    print_section "Создание шаблона Apache VirtualHost"
    
    TEMPLATE_PATH="$HOME_DIR/vhost-template-apache.conf"
    
    cat > "$TEMPLATE_PATH" << 'TEMPLATE'
# Apache VirtualHost Template
# Apache использует порты 8080 и 8443 (Nginx на 80 и 443)
#
# Замените SITENAME на имя вашего сайта (например: mysite.test)
# Замените USERNAME на ваше имя пользователя
# Замените ROOTPATH на путь к public директории проекта
# Замените PHPPORT на порт PHP-FPM (8.1→9081, 8.2→9082, 8.3→9083, 8.4→9084)

Define ROOT "ROOTPATH"
Define SITE "SITENAME"

<VirtualHost *:8080>
    DocumentRoot "${ROOT}"
    ServerName ${SITE}
    ServerAlias *.${SITE}
    ErrorLog ${ROOT}/error8080.log
    <Directory "${ROOT}">
        AllowOverride All
        Require all granted
        Options Indexes FollowSymLinks
        <IfModule dir_module>
            DirectoryIndex index.php
        </IfModule>
        <IfModule mpm_itk_module>
            AssignUserId USERNAME USERNAME
        </IfModule>
    </Directory>
    
    <FilesMatch \.php$>
        SetHandler "proxy:fcgi://127.0.0.1:PHPPORT"
    </FilesMatch>
</VirtualHost>

<VirtualHost *:8443>
    DocumentRoot "${ROOT}"
    ServerName ${SITE}
    ServerAlias *.${SITE}
    ErrorLog ${ROOT}/error8443.log
    <Directory "${ROOT}">
        AllowOverride All
        Require all granted
        Options Indexes FollowSymLinks
        <IfModule dir_module>
            DirectoryIndex index.php
        </IfModule>
        <IfModule mpm_itk_module>
            AssignUserId USERNAME USERNAME
        </IfModule>
    </Directory>

    <FilesMatch \.php$>
        SetHandler "proxy:fcgi://127.0.0.1:PHPPORT"
    </FilesMatch>

    SSLEngine on
    SSLCertificateFile      "/etc/ssl/certs/SITENAME.pem"
    SSLCertificateKeyFile   "/etc/ssl/private/SITENAME-key.pem"
</VirtualHost>
TEMPLATE

    print_success "Шаблон создан: $TEMPLATE_PATH"
    print_info "Инструкция по созданию VirtualHost:"
    print_info "1. Создайте сертификат: mkcert site.test '*.site.test' localhost 127.0.0.1"
    print_info "2. Скопируйте сертификаты:"
    print_info "   sudo cp site.test+4.pem /etc/ssl/certs/site.pem"
    print_info "   sudo cp site.test+4-key.pem /etc/ssl/private/site-key.pem"
    print_info "3. Скопируйте шаблон и отредактируйте:"
    print_info "   sudo cp $TEMPLATE_PATH /etc/apache2/sites-available/site.test.conf"
    print_info "4. Активируйте сайт: sudo a2ensite site.test.conf"
    print_info "5. Добавьте в /etc/hosts: 127.0.0.1 site.test www.site.test"
    print_info "6. Перезапустите Apache: sudo service apache2 restart"
}

#===============================================================================
# Функция: Создание шаблона Nginx VirtualHost
#===============================================================================
create_nginx_vhost_template() {
    print_section "Создание шаблона Nginx VirtualHost"
    
    TEMPLATE_PATH="$HOME_DIR/vhost-template-nginx.conf"
    
    cat > "$TEMPLATE_PATH" << 'TEMPLATE'
# Nginx VirtualHost Template
# Замените SITENAME на имя вашего сайта (например: mysite.test)
# Замените ROOTPATH на путь к public директории проекта
# Замените PHPPORT на порт PHP-FPM (8.1→9081, 8.2→9082, 8.3→9083, 8.4→9084)

server {
    listen 80;
    listen [::]:80;
    server_name SITENAME;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    root ROOTPATH;
    index index.php index.html index.htm;

    server_name SITENAME;

    ssl_certificate      /etc/ssl/certs/SITENAME.pem;
    ssl_certificate_key  /etc/ssl/private/SITENAME-key.pem;

    ssl_session_timeout  1d;
    ssl_session_cache    shared:SSL:50m;
    ssl_session_tickets  off;

    ssl_protocols              TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers  on;

    add_header Strict-Transport-Security max-age=15768000;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass 127.0.0.1:PHPPORT;
    }
}
TEMPLATE

    print_success "Шаблон создан: $TEMPLATE_PATH"
    print_info "Инструкция по созданию Nginx VirtualHost:"
    print_info "1. Создайте сертификат: mkcert site.test '*.site.test' localhost 127.0.0.1"
    print_info "2. Скопируйте сертификаты"
    print_info "3. Скопируйте шаблон: sudo cp $TEMPLATE_PATH /etc/nginx/sites-available/site.test"
    print_info "4. Создайте симлинк: sudo ln -s /etc/nginx/sites-available/site.test /etc/nginx/sites-enabled/"
    print_info "5. Добавьте в /etc/hosts: 127.0.0.1 site.test www.site.test"
    print_info "6. Проверьте конфиг: sudo nginx -t"
    print_info "7. Перезапустите Nginx: sudo service nginx reload"
}

#===============================================================================
# Функция: Вывод справки по использованию
#===============================================================================
show_help() {
    echo -e "${GREEN}Настройка DEV окружения для Ubuntu 24.04${NC}"
    echo ""
    echo "Использование: $0 [опция]"
    echo ""
    echo -e "${YELLOW}Установка:${NC}"
    echo "  all              - Установить всё"
    echo "  update           - Обновить систему"
    echo "  base             - Установить базовые пакеты"
    echo "  zsh              - Установить ZSH + Oh My Zsh + Powerlevel10k"
    echo ""
    echo -e "${YELLOW}Web-серверы:${NC}"
    echo "  apache           - Установить Apache2"
    echo "  nginx            - Установить Nginx"
    echo ""
    echo -e "${YELLOW}PHP:${NC}"
    echo "  php              - Установить PHP (8.1, 8.2, 8.3, 8.4)"
    echo "  php-fpm          - Настроить PHP-FPM для Nginx"
    echo "  xdebug           - Настроить Xdebug"
    echo ""
    echo -e "${YELLOW}Базы данных и кэш:${NC}"
    echo "  mariadb          - Установить MariaDB"
    echo "  postgresql       - Установить PostgreSQL"
    echo "  redis            - Установить Redis"
    echo "  memcached        - Установить Memcached"
    echo ""
    echo -e "${YELLOW}Инструменты:${NC}"
    echo "  mkcert           - Установить mkcert (SSL сертификаты)"
    echo "  go               - Установить Go"
    echo "  mailhog          - Установить MailHog"
    echo "  composer         - Установить Composer"
    echo "  symfony          - Установить Symfony CLI"
    echo "  nvm              - Установить NVM (Node.js)"
    echo "  laravel          - Установить Laravel Installer"
    echo "  docker           - Установить Docker"
    echo ""
    echo -e "${YELLOW}Настройка:${NC}"
    echo "  git              - Настроить Git (имя, email, алиасы)"
    echo "  ssh              - Сгенерировать SSH ключи"
    echo "  dev-script       - Установить скрипт 'dev' для управления сервисами"
    echo "  mailhog-service  - Создать systemd сервис для MailHog"
    echo "  new-project      - Установить скрипт 'new-project'"
    echo "  test-hosts       - Создать тестовые хосты (Apache+PHP8.4, Nginx+PHP8.4)"
    echo "  templates        - Создать шаблоны VirtualHost"
    echo "  scripts          - Установить все скрипты (dev, new-project)"
    echo ""
    echo -e "${YELLOW}Приложения:${NC}"
    echo "  apps             - VS Code, Chrome, Cursor, Obsidian, Thunderbird, FileZilla, PhpStorm"
    echo ""
    echo -e "${YELLOW}Другое:${NC}"
    echo "  extras           - Дополнительный софт (Papirus icons)"
    echo "  fonts            - Установить шрифты Meslo Nerd Font"
    echo "  health           - Проверка работоспособности окружения"
    echo "  export           - Экспорт конфигурации (для переноса)"
    echo "  import           - Импорт конфигурации"
    echo "  backups          - Показать список бэкапов"
    echo "  menu             - Интерактивное меню"
    echo "  help             - Показать эту справку"
    echo ""
    echo -e "${YELLOW}Флаги:${NC}"
    echo "  --no-input         - Пропустить ввод параметров (для автоматизации)"
    echo ""
    echo -e "${BLUE}Примеры:${NC}"
    echo "  $0 all              - Полная установка (с вводом параметров)"
    echo "  $0 all --no-input   - Полная установка без вопросов"
    echo "  $0 php composer     - Установить только PHP и Composer"
    echo "  $0 menu             - Запустить интерактивное меню"
    echo ""
    echo -e "${BLUE}После установки:${NC}"
    echo "  dev start           - Запустить все сервисы"
    echo "  dev status          - Показать статус сервисов"
    echo "  new-project site.test - Создать новый проект"
}

#===============================================================================
# Функция: Интерактивное меню
#===============================================================================
show_menu() {
    while true; do
        clear
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║         НАСТРОЙКА DEV ОКРУЖЕНИЯ ДЛЯ UBUNTU 24.04               ║${NC}"
        echo -e "${GREEN}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}УСТАНОВКА:${NC}                                                   ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   1)  Установить ВСЁ (полная установка)                        ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   2)  Обновить систему                                         ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   3)  Установить базовые пакеты                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}WEB + PHP:${NC}                                                    ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   4)  Apache2              5)  Nginx                           ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   6)  PHP (8.1-8.4)        7)  Настроить PHP-FPM               ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}БАЗЫ ДАННЫХ И КЭШ:${NC}                                            ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   8)  MariaDB              9)  PostgreSQL                      ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  10)  Redis               11)  Memcached                       ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}ИНСТРУМЕНТЫ:${NC}                                                  ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  13)  Composer + Laravel + Symfony                             ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  14)  NVM (Node.js)       15)  Docker                          ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  16)  Go + MailHog        17)  ZSH + Oh My Zsh                 ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}НАСТРОЙКА:${NC}                                                    ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  18)  Настроить Git       19)  SSH ключи                       ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  20)  Скрипты (dev, new-project)                               ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  21)  Шрифты Meslo Nerd Font                                   ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}ПРИЛОЖЕНИЯ:${NC}                                                   ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  22)  VS Code, Chrome, Cursor, Obsidian, PhpStorm и др.        ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}УТИЛИТЫ:${NC}                                                      ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  23)  Health Check (проверка окружения)                        ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  24)  Экспорт конфигурации                                     ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  25)  Импорт конфигурации                                      ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   0)  Выход                                                    ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        read -p "Выберите опцию [0-25]: " choice
        
        case $choice in
            1)  run_prechecks && update_system && install_base_packages && install_zsh && \
                create_directories && install_apache && install_php && configure_php_fpm && \
                configure_xdebug && install_mkcert && install_go && install_mailhog && \
                configure_php_mailhog && install_mariadb && install_postgresql && \
                install_redis && install_memcached && \
                install_nginx && install_composer && install_symfony && install_nvm && \
                install_laravel && install_docker && install_extras && install_apps && \
                configure_git && \
                generate_ssh_keys && create_dev_script && create_new_project_script && \
                create_mailhog_service && install_meslo_fonts && \
                create_test_hosts && \
                create_apache_vhost_template && create_nginx_vhost_template
                ;;
            2)  run_prechecks && update_system ;;
            3)  run_prechecks && install_base_packages ;;
            4)  run_prechecks && install_apache ;;
            5)  run_prechecks && install_nginx ;;
            6)  run_prechecks && install_php ;;
            7)  configure_php_fpm ;;
            8)  run_prechecks && install_mariadb ;;
            9)  run_prechecks && install_postgresql ;;
            10) run_prechecks && install_redis ;;
            11) run_prechecks && install_memcached ;;
            13) run_prechecks && install_composer && install_symfony && install_laravel ;;
            14) run_prechecks && install_nvm ;;
            15) run_prechecks && install_docker ;;
            16) run_prechecks && install_go && install_mailhog && create_mailhog_service ;;
            17) run_prechecks && install_zsh ;;
            18) configure_git ;;
            19) generate_ssh_keys ;;
            20) create_dev_script && create_new_project_script ;;
            21) install_meslo_fonts ;;
            22) run_prechecks && install_apps ;;
            23) health_check ;;
            24) export_config ;;
            25) import_config ;;
            0)  
                print_success "До свидания!"
                exit 0 
                ;;
            *)  
                print_error "Неверный выбор"
                ;;
        esac
        
        echo ""
        read -p "Нажмите Enter для продолжения..."
    done
}

#===============================================================================
# Главная функция
#===============================================================================
main() {
    # Если аргументы не переданы, показываем меню
    if [ $# -eq 0 ]; then
        show_menu
        exit 0
    fi
    
    # Проверка на запуск справки или меню (без проверок)
    if [[ "$1" == "help" || "$1" == "--help" || "$1" == "-h" ]]; then
        show_help
        exit 0
    fi
    
    if [[ "$1" == "menu" ]]; then
        show_menu
        exit 0
    fi
    
    if [[ "$1" == "backups" ]]; then
        list_backups
        exit 0
    fi
    
    # Запуск проверок перед установкой
    run_prechecks
    
    print_section "Настройка DEV окружения для Ubuntu 24.04"
    print_info "Пользователь: $USERNAME"
    print_info "Домашняя директория: $HOME_DIR"
    print_info "WWW директория: $WWW_DIR"
    print_info "Лог-файл: $LOG_FILE"
    
    # Проверка флагов
    local is_full_install=false
    local no_input=false
    
    for arg in "$@"; do
        case "$arg" in
            all) is_full_install=true ;;
            --no-input|--noinput|-y) no_input=true; SKIP_INPUT=true ;;
        esac
    done
    
    # Сбор параметров для полной установки (если не указан --no-input)
    if [ "$is_full_install" = true ] && [ "$no_input" = false ]; then
        collect_user_input
    fi
    
    # Обработка аргументов
    for arg in "$@"; do
        case $arg in
            all)
                update_system
                install_base_packages
                install_zsh
                create_directories
                install_apache
                install_php
                configure_php_fpm
                configure_xdebug
                install_mkcert
                install_go
                install_mailhog
                configure_php_mailhog
                install_mariadb
                install_postgresql
                install_redis
                install_memcached
                install_nginx
                install_composer
                install_symfony
                install_nvm
                install_laravel
                install_docker
                install_extras
                install_apps
                configure_git
                generate_ssh_keys
                create_dev_script
                create_new_project_script
                create_mailhog_service
                install_meslo_fonts
                create_test_hosts
                create_apache_vhost_template
                create_nginx_vhost_template
                ;;
            update)
                update_system
                ;;
            base)
                install_base_packages
                ;;
            zsh)
                install_zsh
                ;;
            apache)
                install_apache
                ;;
            php)
                install_php
                ;;
            php-fpm)
                configure_php_fpm
                ;;
            mkcert)
                install_mkcert
                ;;
            go)
                install_go
                ;;
            mailhog)
                install_mailhog
                ;;
            mailhog-service)
                create_mailhog_service
                ;;
            xdebug)
                configure_xdebug
                ;;
            mariadb)
                install_mariadb
                ;;
            postgresql)
                install_postgresql
                ;;
            redis)
                install_redis
                ;;
            memcached)
                install_memcached
                ;;
            nginx)
                install_nginx
                ;;
            composer)
                install_composer
                ;;
            symfony)
                install_symfony
                ;;
            nvm)
                install_nvm
                ;;
            laravel)
                install_laravel
                ;;
            docker)
                install_docker
                ;;
            apps)
                install_apps
                ;;
            extras)
                install_extras
                ;;
            fonts)
                install_meslo_fonts
                ;;
            health)
                health_check
                ;;
            export)
                export_config
                ;;
            import)
                import_config
                ;;
            git)
                configure_git
                ;;
            ssh)
                generate_ssh_keys
                ;;
            dev-script)
                create_dev_script
                ;;
            new-project)
                create_new_project_script
                ;;
            test-hosts)
                create_test_hosts
                ;;
            scripts)
                create_dev_script
                create_new_project_script
                ;;
            templates)
                create_apache_vhost_template
                create_nginx_vhost_template
                ;;
            help|--help|-h)
                show_help
                exit 0
                ;;
            menu)
                show_menu
                exit 0
                ;;
            backups)
                list_backups
                ;;
            *)
                print_error "Неизвестная опция: $arg"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Вывод итоговой сводки для полной установки
    if [ "$is_full_install" = true ]; then
        show_final_summary
    else
        print_section "Установка завершена!"
        print_info "Лог сохранён: $LOG_FILE"
        print_warning "Рекомендуется перезапустить терминал или выполнить: source ~/.zshrc"
        
        # Вывод неудачных загрузок
        if [ ${#FAILED_DOWNLOADS[@]} -gt 0 ]; then
            echo ""
            echo -e "${RED}❌ Не удалось скачать:${NC}"
            for item in "${FAILED_DOWNLOADS[@]}"; do
                echo -e "  ${RED}•${NC} $item"
            done
            echo ""
            print_warning "Попробуйте скачать вручную или запустите скрипт повторно"
        fi
        
        # Вывод собранных рекомендаций
        if [ ${#RECOMMENDATIONS[@]} -gt 0 ]; then
            echo ""
            print_info "Рекомендации:"
            for rec in "${RECOMMENDATIONS[@]}"; do
                echo "  • $rec"
            done
        fi
        
        echo ""
        print_info "Полезные команды:"
        print_info "  dev start        — запустить все сервисы"
        print_info "  dev status       — показать статус сервисов"
        print_info "  new-project X    — создать новый проект"
    fi
}

# Запуск главной функции с переданными аргументами
main "$@"

