# lib/lang.sh — auto-split from setup-dev-env.sh
# shellcheck shell=bash

show_lang_help() {
    echo -e "${GREEN}Управление версиями языков${NC}"
    echo ""
    echo "Использование: $0 lang <команда> [аргументы]"
    echo ""
    echo "  list                          — конфиг, state и установленные бинарники"
    echo "  add php <ver>                 — установить PHP + FPM + xdebug"
    echo "  add go [ver]                  — установить/заменить Go (по умолчанию из versions.env)"
    echo "  add node <ver|--lts>          — nvm install"
    echo "  update php                    — apt upgrade установленных php*"
    echo "  update go [ver]               — обновить Go (--force)"
    echo "  update node [--lts|<ver>]     — nvm install / reinstall"
    echo "  default php <ver>             — update-alternatives --set php"
    echo "  default node <ver|--lts>      — nvm alias default"
    echo "  remove php <ver>              — apt remove php<ver>* (с подтверждением)"
    echo ""
    echo "Примеры:"
    echo "  $0 lang list"
    echo "  $0 lang add php 8.5"
    echo "  $0 lang update go"
    echo "  $0 lang add node 22"
    echo "  $0 lang default php 8.4"
}

load_nvm() {
    export NVM_DIR="${NVM_DIR:-$HOME_DIR/.nvm}"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # shellcheck disable=SC1090
        set +u
        # shellcheck source=/dev/null
        . "$NVM_DIR/nvm.sh"
        set -euo pipefail
        return 0
    fi
    return 1
}

lang_list() {
    print_section "Языки — список версий"
    
    echo -e "${CYAN}=== Config (versions.env) ===${NC}"
    echo "  PHP_SUPPORTED: $PHP_SUPPORTED"
    echo "  PHP_LEGACY:    $PHP_LEGACY"
    echo "  PHP_DEFAULT:   $PHP_DEFAULT"
    echo "  GO_VERSION:    $GO_VERSION"
    echo "  NVM_VERSION:   $NVM_VERSION"
    echo ""
    
    echo -e "${CYAN}=== PHP (бинарники) ===${NC}"
    local v found_php=false
    for bin in /usr/bin/php[0-9]*; do
        if [ -x "$bin" ]; then
            found_php=true
            echo -e "  ${GREEN}✓${NC} $(basename "$bin"): $($bin -v 2>/dev/null | head -1)"
        fi
    done
    if [ "$found_php" = false ]; then
        echo -e "  ${YELLOW}○${NC} PHP не найден в /usr/bin/php*"
    fi
    if command -v php &>/dev/null; then
        echo "  CLI default: $(php -v 2>/dev/null | head -1)"
    fi
    echo ""
    
    echo -e "${CYAN}=== Go ===${NC}"
    if command -v go &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $(go version)"
    else
        echo -e "  ${YELLOW}○${NC} Go не установлен"
    fi
    echo ""
    
    echo -e "${CYAN}=== Node (nvm) ===${NC}"
    if load_nvm; then
        echo -e "  ${GREEN}✓${NC} NVM: $NVM_DIR"
        nvm ls 2>/dev/null | head -20 || true
        if command -v node &>/dev/null; then
            echo "  current node: $(node -v) | npm: $(npm -v 2>/dev/null || echo '?')"
        fi
    else
        echo -e "  ${YELLOW}○${NC} NVM не установлен ($0 nvm  или  lang add node … после nvm)"
    fi
    echo ""
    
    echo -e "${CYAN}=== State ($STATE_FILE) ===${NC}"
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "  (пусто)"
    fi
}

lang_add_php() {
    local ver="${1:-}"
    if [ -z "$ver" ]; then
        print_error "Укажите версию: lang add php 8.5"
        return 1
    fi
    install_php_version "$ver" || return 1
    configure_php_fpm "$ver"
    configure_xdebug
    configure_php_mailhog || true
    # расширения кэша при наличии сервисов
    if is_command_exists redis-server; then
        sudo apt-get install -y "php${ver}-redis" 2>/dev/null || true
    fi
    if is_command_exists memcached; then
        sudo apt-get install -y "php${ver}-memcached" 2>/dev/null || true
    fi
    print_success "PHP $ver готов (FPM порт 90${ver//./})"
    print_info "Добавьте $ver в PHP_SUPPORTED в config/versions.env, если нужна полная установка all"
}

lang_update_php() {
    print_section "Обновление установленных PHP"
    local pkgs=()
    local ver
    # из бинарников
    for bin in /usr/bin/php[0-9]*; do
        [ -x "$bin" ] || continue
        ver=$(basename "$bin" | sed 's/^php//')
        pkgs+=("php${ver}-cli" "php${ver}-fpm" "php${ver}-common")
    done
    if [ ${#pkgs[@]} -eq 0 ]; then
        print_warning "Установленные PHP не найдены"
        return 0
    fi
    print_info "apt upgrade: ${pkgs[*]}"
    sudo apt-get update
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -y "${pkgs[@]}"; then
        print_success "PHP пакеты обновлены"
        state_set "UPDATED_AT" "$(date -Iseconds)"
    else
        print_warning "Часть пакетов PHP не обновилась"
        return 1
    fi
}

lang_default_php() {
    local ver="${1:-}"
    if [ -z "$ver" ]; then
        print_error "Укажите версию: lang default php 8.4"
        return 1
    fi
    local php_path="/usr/bin/php${ver}"
    if [ ! -x "$php_path" ]; then
        print_error "Не найден $php_path — сначала: lang add php $ver"
        return 1
    fi
    sudo update-alternatives --set php "$php_path"
    print_success "PHP CLI по умолчанию: $($php_path -v | head -1)"
    state_set "PHP_DEFAULT_CLI" "$ver"
}

lang_remove_php() {
    local ver="${1:-}"
    if [ -z "$ver" ]; then
        print_error "Укажите версию: lang remove php 8.1"
        return 1
    fi
    print_warning "Будут удалены пакеты php${ver}-*"
    local reply=""
    if [ "$SKIP_INPUT" != true ]; then
        read -r -p "Продолжить? [y/N]: " reply || true
        if [[ ! "${reply:-}" =~ ^[Yy]$ ]]; then
            print_info "Отменено"
            return 0
        fi
    fi
    sudo apt-get remove --purge -y "php${ver}-*" 2>/dev/null || true
    sudo apt-get autoremove -y 2>/dev/null || true
    print_success "PHP $ver удалён (если пакеты были установлены)"
    # обновить PHP_INSTALLED в state — пересобрать
    local remaining=""
    local bin
    for bin in /usr/bin/php[0-9]*; do
        [ -x "$bin" ] || continue
        remaining="$remaining $(basename "$bin" | sed 's/^php//')"
    done
    remaining=$(echo "$remaining" | xargs)
    state_set "PHP_INSTALLED" "$remaining"
}

lang_add_go() {
    local ver="${1:-$GO_VERSION}"
    install_go "$ver" --force
}

lang_update_go() {
    local ver="${1:-$GO_VERSION}"
    install_go "$ver" --force
}

lang_add_node() {
    local ver="${1:-}"
    if [ -z "$ver" ]; then
        print_error "Укажите версию: lang add node 22  или  lang add node --lts"
        return 1
    fi
    if ! load_nvm; then
        print_info "NVM не найден — устанавливаем..."
        install_nvm || return 1
        load_nvm || return 1
    fi
    if [ "$ver" = "--lts" ] || [ "$ver" = "lts" ]; then
        nvm install --lts
        nvm alias default 'lts/*' 2>/dev/null || nvm alias default node
    else
        nvm install "$ver"
        nvm alias default "$ver"
    fi
    local node_v
    node_v=$(node -v 2>/dev/null || echo "$ver")
    state_set "NODE_INSTALLED" "$node_v"
    state_set "UPDATED_AT" "$(date -Iseconds)"
    print_success "Node установлен: $node_v"
}

lang_update_node() {
    lang_add_node "${1:---lts}"
}

lang_default_node() {
    local ver="${1:-}"
    if [ -z "$ver" ]; then
        print_error "Укажите версию: lang default node 22"
        return 1
    fi
    if ! load_nvm; then
        print_error "NVM не установлен"
        return 1
    fi
    if [ "$ver" = "--lts" ] || [ "$ver" = "lts" ]; then
        nvm alias default 'lts/*' 2>/dev/null || nvm use --lts
    else
        nvm alias default "$ver"
        nvm use "$ver"
    fi
    state_set "NODE_DEFAULT" "$(node -v 2>/dev/null || echo "$ver")"
    print_success "Node default: $(node -v)"
}

cmd_lang() {
    local sub="${1:-}"
    shift || true
    
    case "$sub" in
        ""|help|--help|-h)
            show_lang_help
            return 0
            ;;
        list)
            lang_list
            return 0
            ;;
        add)
            run_prechecks
            local kind="${1:-}"
            local arg="${2:-}"
            case "$kind" in
                php) lang_add_php "$arg" ;;
                go)  lang_add_go "${arg:-$GO_VERSION}" ;;
                node) lang_add_node "$arg" ;;
                *) print_error "lang add: php|go|node"; show_lang_help; return 1 ;;
            esac
            ;;
        update)
            run_prechecks
            local kind="${1:-}"
            local arg="${2:-}"
            case "$kind" in
                php) lang_update_php ;;
                go)  lang_update_go "${arg:-$GO_VERSION}" ;;
                node) lang_update_node "${arg:---lts}" ;;
                *) print_error "lang update: php|go|node"; show_lang_help; return 1 ;;
            esac
            ;;
        default)
            local kind="${1:-}"
            local arg="${2:-}"
            case "$kind" in
                php) lang_default_php "$arg" ;;
                node) lang_default_node "$arg" ;;
                go) print_info "Go — одна установка в /usr/local/go; default не требуется" ;;
                *) print_error "lang default: php|node"; show_lang_help; return 1 ;;
            esac
            ;;
        remove)
            run_prechecks
            local kind="${1:-}"
            local arg="${2:-}"
            case "$kind" in
                php) lang_remove_php "$arg" ;;
                *) print_error "Пока поддерживается: lang remove php <ver>"; return 1 ;;
            esac
            ;;
        *)
            print_error "Неизвестная команда lang: $sub"
            show_lang_help
            return 1
            ;;
    esac
}

