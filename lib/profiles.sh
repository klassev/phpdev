# shellcheck shell=bash
# Профили установки: profiles/*.conf

list_profiles() {
    print_section "Доступные профили"
    local f name desc
    if ! compgen -G "$PHPDEV_ROOT/profiles/*.conf" >/dev/null 2>&1; then
        print_warning "Нет файлов в $PHPDEV_ROOT/profiles/"
        return 0
    fi
    for f in "$PHPDEV_ROOT/profiles/"*.conf; do
        name=$(basename "$f" .conf)
        desc=$(grep -E '^# DESC:' "$f" 2>/dev/null | head -1 | sed 's/^# DESC:[[:space:]]*//')
        echo -e "  ${GREEN}$name${NC}  ${desc:-}"
    done
    echo ""
    print_info "Запуск: $0 profile <name> [--no-input]"
}

run_profile() {
    local name="${1:-}"
    if [ -z "$name" ]; then
        list_profiles
        return 0
    fi
    
    local file="$PHPDEV_ROOT/profiles/${name}.conf"
    if [ ! -f "$file" ]; then
        print_error "Профиль не найден: $file"
        list_profiles
        return 1
    fi
    
    # shellcheck disable=SC1090
    set +u
    # shellcheck source=/dev/null
    source "$file"
    set -euo pipefail
    
    if [ "${PROFILE_FULL_INSTALL:-false}" = true ]; then
        print_section "Профиль: $name (полная установка)"
        run_prechecks
        if [ "$SKIP_INPUT" != true ]; then
            collect_user_input
        fi
        run_full_install
        show_final_summary
        return 0
    fi
    
    if [ -z "${PROFILE_STEPS:-}" ]; then
        print_error "В профиле не задан PROFILE_STEPS"
        return 1
    fi
    
    print_section "Профиль: $name"
    print_info "${PROFILE_DESC:-}"
    run_prechecks
    
    local step
    local failed=0
    # shellcheck disable=SC2086
    for step in $PROFILE_STEPS; do
        if declare -F "$step" >/dev/null 2>&1; then
            print_info "→ $step"
            if ! "$step"; then
                print_warning "Шаг $step завершился с ошибкой"
                failed=1
            fi
        else
            print_error "Неизвестная функция в профиле: $step"
            failed=1
        fi
    done
    
    if [ "$failed" -eq 0 ]; then
        print_success "Профиль $name выполнен"
    else
        print_warning "Профиль $name завершён с предупреждениями"
    fi
    return "$failed"
}

show_profile_help() {
    echo -e "${GREEN}Профили установки${NC}"
    echo ""
    echo "Использование: $0 profile [name] [--no-input]"
    echo "               $0 profile list"
    echo ""
    list_profiles
}
