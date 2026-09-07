# lib/install/php.sh — auto-split from setup-dev-env.sh
# shellcheck shell=bash

ensure_php_repo() {
    if ! apt-cache show php8.2-fpm &>/dev/null; then
        print_info "Добавление репозитория ppa:ondrej/php..."
        sudo add-apt-repository -y ppa:ondrej/php
        sudo apt update
    fi
}

install_php_version() {
    local version="$1"
    local pkgs=()
    
    case "$version" in
        7.*|8.*) ;;
        *)
            print_error "Неподдерживаемая версия PHP: $version"
            print_info "Ожидается вид 7.x или 8.x (например 8.4, 8.5)"
            print_info "В versions.env сейчас: PHP_SUPPORTED=$PHP_SUPPORTED"
            return 1
            ;;
    esac
    
    if [[ "$version" == 7.* ]]; then
        print_warning "PHP $version — EOL и на Ubuntu 24.04 через apt обычно недоступен"
        print_info "Для legacy-проектов предпочтителен Docker (см. IMPROVEMENT_PLAN.md, этап 7)"
    fi
    
    print_section "Установка PHP $version"
    
    if is_command_exists "php$version"; then
        print_warning "PHP $version уже установлен: $(php$version -v | head -1)"
        print_info "Пропускаем установку PHP $version"
        record_php_installed "$version"
        return 0
    fi
    
    ensure_php_repo
    
    if ! apt-cache show "php${version}-fpm" &>/dev/null; then
        print_warning "PHP $version недоступен для вашей версии Ubuntu"
        if [[ "$version" == 7.* ]]; then
            print_info "Рекомендация: поднимите PHP $version в Docker, а не через apt"
        fi
        return 1
    fi
    
    print_info "Установка PHP $version..."
    
    pkgs=(
        "php${version}-cli"
        "php${version}-fpm"
        "php${version}-common"
        "php${version}-bcmath"
        "php${version}-bz2"
        "php${version}-curl"
        "php${version}-gd"
        "php${version}-gmp"
        "php${version}-intl"
        "php${version}-mbstring"
        "php${version}-mysql"
        "php${version}-opcache"
        "php${version}-pgsql"
        "php${version}-readline"
        "php${version}-xml"
        "php${version}-zip"
        "php${version}-sqlite3"
        "php${version}-xdebug"
        "libapache2-mod-php${version}"
    )
    
    # PHP 7.4 требует отдельный пакет json; в 8.x json встроен
    if [ "$version" = "7.4" ]; then
        pkgs+=("php${version}-json")
    fi
    
    if ! sudo apt install -y "${pkgs[@]}"; then
        print_warning "PHP $version не удалось установить (основные пакеты)"
        return 1
    fi
    
    # Опциональные расширения (могут отсутствовать в новых минорных релизах)
    local opt
    for opt in "php${version}-imap" "php${version}-gettext" "php${version}-dev"; do
        if apt-cache show "$opt" &>/dev/null; then
            sudo apt install -y "$opt" 2>/dev/null || print_warning "Опциональный пакет пропущен: $opt"
        fi
    done
    
    sudo systemctl disable "php${version}-fpm.service" 2>/dev/null || true
    print_success "PHP $version установлен"
    print_info "PHP-FPM порт: 90${version//./}"
    print_info "Переключение CLI: sudo update-alternatives --config php"
    print_info "Или: $0 lang default php $version"
    record_php_installed "$version"
    return 0
}

install_php() {
    print_section "Установка PHP (${PHP_SUPPORTED_VERSIONS[*]})"
    
    ensure_php_repo
    
    local failed=0
    local version
    for version in "${PHP_SUPPORTED_VERSIONS[@]}"; do
        if ! install_php_version "$version"; then
            failed=1
        fi
    done
    
    print_success "Установка PHP завершена"
    print_info "Для переключения версии PHP: sudo update-alternatives --config php"
    print_info "PHP 7.x на Ubuntu 24.04 через apt не ставится — для legacy используйте Docker"
    
    if [ "$failed" -ne 0 ]; then
        print_warning "Некоторые версии PHP установить не удалось — см. лог выше"
    fi
}

configure_php_fpm() {
    local versions=("$@")
    
    if [ ${#versions[@]} -eq 0 ]; then
        versions=("${PHP_ALL_KNOWN_VERSIONS[@]}")
        print_section "Настройка PHP-FPM"
    else
        print_section "Настройка PHP-FPM (${versions[*]})"
    fi
    
    # Порты: 8.1→9081 … 8.4→9084; legacy 7.x→907x если установлены
    
    local configured=0
    for version in "${versions[@]}"; do
        local port="90${version//./}"
        local conf_file="/etc/php/${version}/fpm/pool.d/www.conf"
        
        if [ -f "$conf_file" ]; then
            print_info "Настройка PHP ${version}-FPM на порт $port..."
            
            backup_config "$conf_file"
            
            sudo sed -i "s/www-data/$USERNAME/g" "$conf_file"
            sudo sed -i "s|listen = /run/php/php${version}-fpm.sock|listen = 127.0.0.1:$port|g" "$conf_file"
            
            sudo /etc/init.d/php${version}-fpm restart 2>/dev/null || true
            configured=$((configured + 1))
        fi
    done
    
    if [ "$configured" -eq 0 ]; then
        print_warning "Не найдено установленных PHP-FPM для настройки"
        return 1
    fi
    
    print_success "PHP-FPM настроен"
    print_info "Порты PHP-FPM: 8.1→9081 … 8.5→9085 (legacy 7.x→907x)"
}

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
    for version in "${PHP_ALL_KNOWN_VERSIONS[@]}"; do
        xdebug_ini="/etc/php/${version}/mods-available/xdebug.ini"
        if [ -f "$xdebug_ini" ]; then
            print_info "Настройка Xdebug для PHP $version..."
            echo "$XDEBUG_CONFIG" | sudo tee "$xdebug_ini" > /dev/null
        fi
    done
    
    print_success "Xdebug настроен"
}

configure_php_mail() {
    local catcher="${MAIL_CATCHER:-mailpit}"
    print_section "Настройка PHP sendmail ($catcher)"
    
    local sendmail_cmd
    if [ "$catcher" = "mailhog" ]; then
        sendmail_cmd="/usr/local/bin/mhsendmail"
    else
        # Mailpit встроенный sendmail
        sendmail_cmd='"/usr/local/bin/mailpit" sendmail'
    fi
    
    local version ini_path
    for version in "${PHP_ALL_KNOWN_VERSIONS[@]}"; do
        for ini_path in "/etc/php/${version}/cli/php.ini" "/etc/php/${version}/fpm/php.ini" "/etc/php/${version}/apache2/php.ini"; do
            if [ -f "$ini_path" ]; then
                if grep -q "^sendmail_path" "$ini_path"; then
                    sudo sed -i "s|^sendmail_path.*|sendmail_path = ${sendmail_cmd}|" "$ini_path"
                else
                    echo "sendmail_path = ${sendmail_cmd}" | sudo tee -a "$ini_path" > /dev/null
                fi
            fi
        done
    done
    
    print_success "PHP настроен для $catcher ($sendmail_cmd)"
}

# Совместимость со старым именем
configure_php_mailhog() {
    configure_php_mail
}

