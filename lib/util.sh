# lib/util.sh — health, export, import
# shellcheck shell=bash

health_check() {
    print_section "Health Check — проверка окружения"
    
    local all_ok=true
    
    echo -e "${CYAN}=== Системная информация ===${NC}"
    echo "  ОС: $(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "  Ядро: $(uname -r)"
    echo "  Пользователь: $USERNAME"
    echo ""
    
    echo -e "${CYAN}=== Софт ===${NC}"
    if command -v php &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} PHP CLI: $(php -v | head -1 | cut -d' ' -f2)"
    else
        echo -e "  ${RED}✗${NC} PHP не установлен"; all_ok=false
    fi
    command -v composer &>/dev/null && echo -e "  ${GREEN}✓${NC} Composer: $(composer --version 2>/dev/null | cut -d' ' -f3)" || echo -e "  ${YELLOW}○${NC} Composer"
    command -v node &>/dev/null && echo -e "  ${GREEN}✓${NC} Node.js: $(node -v)" || echo -e "  ${YELLOW}○${NC} Node.js (nvm install --lts)"
    command -v go &>/dev/null && echo -e "  ${GREEN}✓${NC} Go: $(go version | cut -d' ' -f3)" || echo -e "  ${YELLOW}○${NC} Go"
    if command -v docker &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Docker: $(docker --version | cut -d' ' -f3 | tr -d ',')"
        if docker ps &>/dev/null; then
            echo -e "      ${GREEN}✓${NC} без sudo"
        else
            echo -e "      ${RED}✗${NC} нужен sudo / newgrp docker"; all_ok=false
        fi
    else
        echo -e "  ${YELLOW}○${NC} Docker"
    fi
    command -v git &>/dev/null && echo -e "  ${GREEN}✓${NC} Git: $(git --version | cut -d' ' -f3)" || { echo -e "  ${RED}✗${NC} Git"; all_ok=false; }
    command -v mkcert &>/dev/null && echo -e "  ${GREEN}✓${NC} mkcert: $(mkcert -version 2>/dev/null | head -1)" || echo -e "  ${YELLOW}○${NC} mkcert"
    if command -v mailpit &>/dev/null || [ -x /usr/local/bin/mailpit ]; then
        echo -e "  ${GREEN}✓${NC} Mailpit"
    elif [ -f "$HOME_DIR/go/bin/MailHog" ]; then
        echo -e "  ${YELLOW}○${NC} MailHog (legacy) — лучше MAIL_CATCHER=mailpit"
    else
        echo -e "  ${YELLOW}○${NC} Mail catcher не установлен"
    fi
    echo ""
    
    echo -e "${CYAN}=== Сервисы ===${NC}"
    check_service() {
        local service=$1 name=$2
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            echo -e "  ${GREEN}●${NC} $name — работает"
        elif systemctl list-unit-files "${service}.service" 2>/dev/null | grep -q "$service"; then
            echo -e "  ${YELLOW}○${NC} $name — остановлен"
        else
            echo -e "  ${RED}–${NC} $name — не установлен"
        fi
    }
    check_service "apache2" "Apache2"
    check_service "nginx" "Nginx"
    check_service "mariadb" "MariaDB"
    check_service "postgresql" "PostgreSQL"
    check_service "redis-server" "Redis"
    check_service "memcached" "Memcached"
    check_service "mailpit" "Mailpit"
    check_service "mailhog" "MailHog"
    
    echo ""
    echo -e "${CYAN}=== PHP-FPM ===${NC}"
    local fpm_found=false unit ver
    for unit in /lib/systemd/system/php*-fpm.service /usr/lib/systemd/system/php*-fpm.service; do
        [ -f "$unit" ] || continue
        fpm_found=true
        ver=$(basename "$unit" .service)
        check_service "$ver" "$ver"
    done
    [ "$fpm_found" = true ] || echo -e "  ${YELLOW}○${NC} PHP-FPM unit-файлы не найдены"
    
    echo ""
    echo -e "${CYAN}=== Xdebug ===${NC}"
    local xd=false
    for ver in ${PHP_SUPPORTED:-8.1 8.2 8.3 8.4}; do
        if [ -f "/etc/php/${ver}/mods-available/xdebug.ini" ] || ls /etc/php/"$ver"/mods-available/xdebug.ini &>/dev/null; then
            echo -e "  ${GREEN}✓${NC} xdebug.ini для PHP $ver"
            xd=true
        fi
    done
    [ "$xd" = true ] || echo -e "  ${YELLOW}○${NC} xdebug.ini не найдены"
    if command -v php &>/dev/null && php -m 2>/dev/null | grep -qi xdebug; then
        echo -e "  ${GREEN}✓${NC} модуль xdebug загружен в CLI"
    fi
    
    echo ""
    echo -e "${CYAN}=== Порты ===${NC}"
    check_port() {
        local port=$1 name=$2
        if ss -tuln 2>/dev/null | grep -qE ":${port}\\s"; then
            echo -e "  ${GREEN}●${NC} $port ($name) — слушает"
        else
            echo -e "  ${YELLOW}○${NC} $port ($name) — свободен"
        fi
    }
    check_port 80 "Nginx HTTP"
    check_port 443 "Nginx HTTPS"
    check_port 8080 "Apache HTTP"
    check_port 8443 "Apache HTTPS"
    check_port 3306 "MariaDB"
    check_port 5432 "PostgreSQL"
    check_port 6379 "Redis"
    check_port 11211 "Memcached"
    check_port 1025 "Mail SMTP"
    check_port 8025 "Mail UI"
    for ver in ${PHP_SUPPORTED:-8.1 8.2 8.3 8.4}; do
        local p="90${ver//./}"
        check_port "$p" "PHP $ver FPM"
    done
    
    echo ""
    echo -e "${CYAN}=== mkcert CA ===${NC}"
    if command -v mkcert &>/dev/null; then
        local caroot
        caroot=$(mkcert -CAROOT 2>/dev/null || true)
        if [ -n "$caroot" ] && [ -d "$caroot" ]; then
            echo -e "  ${GREEN}✓${NC} CAROOT: $caroot"
        else
            echo -e "  ${YELLOW}○${NC} mkcert есть, CAROOT не определён — mkcert -install"
        fi
    else
        echo -e "  ${YELLOW}○${NC} mkcert не установлен"
    fi
    
    echo ""
    echo -e "${CYAN}=== Директории ===${NC}"
    if [ -d "$WWW_DIR" ]; then
        echo -e "  ${GREEN}✓${NC} WWW: $WWW_DIR ($(ls -1 "$WWW_DIR" 2>/dev/null | wc -l) проектов)"
    else
        echo -e "  ${RED}✗${NC} WWW не создана"
    fi
    if [ -f "$HOME_DIR/.ssh/id_ed25519" ]; then
        echo -e "  ${GREEN}✓${NC} SSH ключ"
    else
        echo -e "  ${YELLOW}○${NC} SSH ключ не создан"
    fi
    
    echo ""
    echo -e "${CYAN}=== Config / state / outdated ===${NC}"
    echo "  PHP_SUPPORTED=$PHP_SUPPORTED  default=$PHP_DEFAULT"
    echo "  GO_VERSION=$GO_VERSION  MAIL_CATCHER=$MAIL_CATCHER"
    if command -v go &>/dev/null; then
        local gv
        gv=$(go version | awk '{print $3}' | sed 's/^go//')
        if [ "$gv" != "$GO_VERSION" ]; then
            echo -e "  ${YELLOW}!${NC} Go установлен $gv, в конфиге $GO_VERSION → lang update go"
        else
            echo -e "  ${GREEN}✓${NC} Go актуален ($gv)"
        fi
    fi
    if [ -f "$STATE_FILE" ]; then
        echo -e "  ${GREEN}✓${NC} $STATE_FILE"
        grep -E '^(PHP_INSTALLED|GO_INSTALLED|NODE_INSTALLED|DB_LAST_UPDATE|UPDATED_AT)=' "$STATE_FILE" 2>/dev/null | sed 's/^/      /' || true
    else
        echo -e "  ${YELLOW}○${NC} state ещё нет"
    fi
    echo "  БД: $0 db status | языки: $0 lang list"
    
    echo ""
    if [ "$all_ok" = true ]; then
        print_success "Базовые компоненты в порядке"
    else
        print_warning "Есть отсутствующие базовые компоненты"
    fi
    print_info "dev start | dev status | $0 db update --dry-run"
}

export_config() {
    print_section "Экспорт конфигурации"
    
    local export_dir="$HOME_DIR/dev-env-export"
    local export_file="$export_dir/dev-env-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    
    mkdir -p "$export_dir"
    
    local tmp_dir
    tmp_dir=$(mktemp -d)
    
    print_info "Сбор конфигурационных файлов..."
    
    mkdir -p "$tmp_dir/configs"
    
    [ -f "$HOME_DIR/.zshrc" ] && cp "$HOME_DIR/.zshrc" "$tmp_dir/configs/"
    [ -f "$HOME_DIR/.p10k.zsh" ] && cp "$HOME_DIR/.p10k.zsh" "$tmp_dir/configs/"
    [ -f "$HOME_DIR/.gitconfig" ] && cp "$HOME_DIR/.gitconfig" "$tmp_dir/configs/"
    [ -f "$HOME_DIR/.ssh/config" ] && cp "$HOME_DIR/.ssh/config" "$tmp_dir/configs/ssh_config"
    
    mkdir -p "$tmp_dir/php"
    local version
    for version in "${PHP_ALL_KNOWN_VERSIONS[@]}"; do
        [ -f "/etc/php/$version/cli/php.ini" ] && \
            cp "/etc/php/$version/cli/php.ini" "$tmp_dir/php/php${version}-cli.ini" 2>/dev/null || true
    done
    
    mkdir -p "$tmp_dir/nginx" "$tmp_dir/apache"
    cp -r /etc/nginx/sites-available/* "$tmp_dir/nginx/" 2>/dev/null || true
    cp /etc/apache2/sites-available/*.conf "$tmp_dir/apache/" 2>/dev/null || true
    
    dpkg --get-selections > "$tmp_dir/packages.list" 2>/dev/null || true
    ls /etc/apt/sources.list.d/ > "$tmp_dir/ppa.list" 2>/dev/null || true
    
    cat > "$tmp_dir/system-info.txt" << EOF
Export date: $(date)
User: $USERNAME
OS: $(lsb_release -ds 2>/dev/null)
PHP: $(php -v 2>/dev/null | head -1)
Node: $(node -v 2>/dev/null || echo "N/A")
Go: $(go version 2>/dev/null || echo "N/A")
EOF
    
    tar -czf "$export_file" -C "$tmp_dir" .
    rm -rf "$tmp_dir"
    
    print_success "Конфигурация экспортирована: $export_file"
    print_info "Размер: $(du -h "$export_file" | cut -f1)"
}

import_config() {
    print_section "Импорт конфигурации (базовый)"
    
    local export_dir="$HOME_DIR/dev-env-export"
    
    if [ ! -d "$export_dir" ]; then
        print_error "Директория экспорта не найдена: $export_dir"
        return 1
    fi
    
    local latest_backup
    latest_backup=$(ls -t "$export_dir"/dev-env-backup-*.tar.gz 2>/dev/null | head -1)
    
    if [ -z "$latest_backup" ]; then
        print_error "Архивы не найдены в $export_dir"
        return 1
    fi
    
    print_info "Найден архив: $latest_backup"
    read -r -p "Импортировать конфигурацию? (y/n): " -n 1 -r || true
    echo
    if [[ ! ${REPLY:-} =~ ^[Yy]$ ]]; then
        return 0
    fi
    
    local tmp_dir
    tmp_dir=$(mktemp -d)
    tar -xzf "$latest_backup" -C "$tmp_dir"
    
    [ -f "$tmp_dir/configs/.zshrc" ] && cp "$tmp_dir/configs/.zshrc" "$HOME_DIR/.zshrc"
    [ -f "$tmp_dir/configs/.gitconfig" ] && cp "$tmp_dir/configs/.gitconfig" "$HOME_DIR/.gitconfig"
    
    rm -rf "$tmp_dir"
    print_success "Базовый импорт завершён (проверьте конфиги вручную)"
}
