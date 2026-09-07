# lib/db.sh — auto-split from setup-dev-env.sh
# shellcheck shell=bash

show_db_help() {
    echo -e "${GREEN}Управление базами данных и кэшем${NC}"
    echo ""
    echo "Использование: $0 db <команда> [аргументы]"
    echo ""
    echo "  status                         — версии и статус сервисов"
    echo "  update [name…]                 — обновить пакеты (все или выбранные)"
    echo "  update --dry-run [name…]       — показать план без изменений"
    echo "  update --no-backup [name…]     — без дампа (только с предупреждением)"
    echo "  update postgresql --major      — разрешить смену major PostgreSQL"
    echo ""
    echo "Имена: mariadb | postgresql | redis | memcached"
    echo ""
    echo "Бэкапы SQL/Redis: $DB_BACKUP_DIR/"
    echo ""
    echo "Примеры:"
    echo "  $0 db status"
    echo "  $0 db update"
    echo "  $0 db update mariadb redis"
    echo "  $0 db update postgresql --dry-run"
}

db_normalize_name() {
    case "$1" in
        mariadb|mysql) echo mariadb ;;
        postgresql|postgres|pgsql) echo postgresql ;;
        redis) echo redis ;;
        memcached|memcache) echo memcached ;;
        *) echo "" ;;
    esac
}

db_service_unit() {
    case "$1" in
        mariadb) echo mariadb ;;
        postgresql) echo postgresql ;;
        redis) echo redis-server ;;
        memcached) echo memcached ;;
    esac
}

db_apt_packages() {
    case "$1" in
        mariadb) echo "mariadb-server mariadb-client" ;;
        postgresql) echo "postgresql postgresql-client" ;;
        redis) echo "redis-server redis-tools" ;;
        memcached) echo "memcached libmemcached-tools" ;;
    esac
}

db_is_installed() {
    case "$1" in
        mariadb) is_command_exists mariadb || is_command_exists mysql ;;
        postgresql) is_command_exists psql ;;
        redis) is_command_exists redis-server ;;
        memcached) is_command_exists memcached ;;
        *) return 1 ;;
    esac
}

db_installed_version() {
    case "$1" in
        mariadb)
            if is_command_exists mariadb; then mariadb --version 2>/dev/null | head -1
            elif is_command_exists mysql; then mysql --version 2>/dev/null | head -1
            else echo "—"; fi
            ;;
        postgresql) psql --version 2>/dev/null | head -1 || echo "—" ;;
        redis) redis-server --version 2>/dev/null | head -1 || echo "—" ;;
        memcached) memcached -h 2>&1 | head -1 || echo "—" ;;
    esac
}

db_apt_candidate() {
    local pkg
    case "$1" in
        mariadb) pkg=mariadb-server ;;
        postgresql) pkg=postgresql ;;
        redis) pkg=redis-server ;;
        memcached) pkg=memcached ;;
        *) return 0 ;;
    esac
    apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/{print $2; exit}'
}

db_service_state() {
    local unit
    unit=$(db_service_unit "$1")
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
        echo "active"
    elif systemctl list-unit-files "$unit.service" 2>/dev/null | grep -q "$unit"; then
        echo "inactive"
    else
        echo "missing"
    fi
}

db_pg_major_installed() {
    if ! is_command_exists psql; then
        echo ""
        return
    fi
    psql --version 2>/dev/null | grep -oE '[0-9]+' | head -1
}

db_pg_major_candidate() {
    local cand
    cand=$(db_apt_candidate postgresql)
    # примеры: 16+257build1.1, 15.8-0ubuntu0.24.04.1
    echo "$cand" | grep -oE '^[0-9]+' | head -1
}

db_status() {
    print_section "БД и кэш — статус"
    local name
    printf "  %-12s %-10s %-22s %s\n" "NAME" "SERVICE" "CANDIDATE" "INSTALLED"
    echo "  ------------------------------------------------------------"
    for name in mariadb postgresql redis memcached; do
        if ! db_is_installed "$name"; then
            printf "  %-12s %-10s %-22s %s\n" "$name" "—" "$(db_apt_candidate "$name")" "не установлен"
            continue
        fi
        printf "  %-12s %-10s %-22s %s\n" \
            "$name" \
            "$(db_service_state "$name")" \
            "$(db_apt_candidate "$name")" \
            "$(db_installed_version "$name")"
    done
    echo ""
    print_info "Бэкапы: $DB_BACKUP_DIR"
    print_info "Обновление: $0 db update [mariadb|postgresql|redis|memcached]"
}

db_ensure_backup_dir() {
    mkdir -p "$DB_BACKUP_DIR"
}

db_backup() {
    local name="$1"
    local stamp
    stamp=$(date +%Y%m%d_%H%M%S)
    db_ensure_backup_dir
    
    case "$name" in
        mariadb)
            local out="$DB_BACKUP_DIR/mariadb-all-${stamp}.sql.gz"
            print_info "Бэкап MariaDB → $out"
            local unit
            unit=$(db_service_unit mariadb)
            sudo systemctl start "$unit" 2>/dev/null || true
            if is_command_exists mariadb-dump; then
                sudo mariadb-dump --all-databases --single-transaction --routines --triggers 2>/dev/null | gzip > "$out"
            else
                sudo mysqldump --all-databases --single-transaction --routines --triggers 2>/dev/null | gzip > "$out"
            fi
            if [ -s "$out" ]; then
                print_success "Бэкап MariaDB: $out ($(du -h "$out" | cut -f1))"
            else
                rm -f "$out"
                print_warning "Бэкап MariaDB пуст или не удался (сервис/права?)"
                return 1
            fi
            ;;
        postgresql)
            local out="$DB_BACKUP_DIR/postgresql-all-${stamp}.sql.gz"
            print_info "Бэкап PostgreSQL → $out"
            sudo systemctl start postgresql 2>/dev/null || true
            if sudo -u postgres pg_dumpall 2>/dev/null | gzip > "$out" && [ -s "$out" ]; then
                print_success "Бэкап PostgreSQL: $out ($(du -h "$out" | cut -f1))"
            else
                rm -f "$out"
                print_warning "Бэкап PostgreSQL пуст или не удался"
                return 1
            fi
            ;;
        redis)
            local out="$DB_BACKUP_DIR/redis-dump-${stamp}.rdb"
            print_info "Бэкап Redis → $out"
            sudo systemctl start redis-server 2>/dev/null || true
            sleep 0.5
            
            # Предпочтительно: снять RDB напрямую через redis-cli --rdb
            if redis-cli --rdb "$out" >/dev/null 2>&1 && [ -s "$out" ]; then
                print_success "Бэкап Redis (redis-cli --rdb): $out ($(du -h "$out" | cut -f1))"
                return 0
            fi
            rm -f "$out" 2>/dev/null || true
            
            # Fallback: SAVE + копия dump.rdb (учёт dir/dbfilename из конфига)
            redis-cli SAVE >/dev/null 2>&1 || true
            local rdb="" dir dbfilename
            dir=$(redis-cli CONFIG GET dir 2>/dev/null | awk 'NR==2{print; exit}')
            dbfilename=$(redis-cli CONFIG GET dbfilename 2>/dev/null | awk 'NR==2{print; exit}')
            if [ -n "$dir" ] && [ -n "$dbfilename" ] && [ -f "${dir}/${dbfilename}" ]; then
                rdb="${dir}/${dbfilename}"
            else
                for cand in /var/lib/redis/dump.rdb /var/lib/redis/*/dump.rdb; do
                    if [ -f "$cand" ]; then rdb="$cand"; break; fi
                done
                # иногда файл только у root
                if [ -z "$rdb" ]; then
                    rdb=$(sudo bash -c 'ls /var/lib/redis/dump.rdb /var/lib/redis/*/dump.rdb 2>/dev/null' | head -1 || true)
                fi
            fi
            if [ -n "$rdb" ] && sudo cp "$rdb" "$out" 2>/dev/null; then
                sudo chown "$USERNAME:$USERNAME" "$out" 2>/dev/null || true
                if [ -s "$out" ]; then
                    print_success "Бэкап Redis: $out"
                    return 0
                fi
            fi
            rm -f "$out" 2>/dev/null || true
            # Пустой/свежий Redis без RDB — не блокируем update
            local marker="$DB_BACKUP_DIR/redis-empty-${stamp}.txt"
            echo "Redis backup skipped or empty at $(date -Iseconds); PING=$(redis-cli ping 2>/dev/null || echo fail)" > "$marker"
            print_warning "dump.rdb не найден (часто на пустом Redis) — маркер: $marker"
            print_info "Обновление продолжится; для жёсткого требования бэкапа используйте заполненный Redis"
            return 0
            ;;
        memcached)
            print_info "Memcached без постоянного хранилища — бэкап не требуется"
            return 0
            ;;
    esac
}

db_smoke_check() {
    local name="$1"
    case "$name" in
        mariadb)
            if sudo mysql -N -e "SELECT 1" 2>/dev/null | grep -q 1 \
                || sudo mariadb -N -e "SELECT 1" 2>/dev/null | grep -q 1; then
                print_success "Smoke MariaDB: OK"
                return 0
            fi
            print_warning "Smoke MariaDB: не удалось выполнить SELECT 1"
            return 1
            ;;
        postgresql)
            if sudo -u postgres psql -tAc "SELECT 1" 2>/dev/null | grep -q 1; then
                print_success "Smoke PostgreSQL: OK"
                return 0
            fi
            print_warning "Smoke PostgreSQL: не удалось выполнить SELECT 1"
            return 1
            ;;
        redis)
            if redis-cli ping 2>/dev/null | grep -qi PONG; then
                print_success "Smoke Redis: PONG"
                return 0
            fi
            print_warning "Smoke Redis: нет PONG"
            return 1
            ;;
        memcached)
            if printf "stats\nquit\n" | nc -w 1 127.0.0.1 11211 2>/dev/null | grep -qi STAT; then
                print_success "Smoke Memcached: OK"
                return 0
            fi
            print_warning "Smoke Memcached: порт 11211 не ответил"
            return 1
            ;;
    esac
}

db_update_one() {
    local name="$1"
    local dry_run="$2"
    local no_backup="$3"
    local allow_major="$4"
    
    if ! db_is_installed "$name"; then
        print_warning "$name не установлен — пропуск (сначала: $0 $name)"
        return 0
    fi
    
    local pkgs unit
    pkgs=$(db_apt_packages "$name")
    unit=$(db_service_unit "$name")
    
    print_section "Обновление: $name"
    print_info "Пакеты: $pkgs"
    print_info "Сейчас: $(db_installed_version "$name")"
    print_info "Candidate: $(db_apt_candidate "$name")"
    
    if [ "$name" = "postgresql" ]; then
        local cur maj
        cur=$(db_pg_major_installed)
        maj=$(db_pg_major_candidate)
        if [ -n "$cur" ] && [ -n "$maj" ] && [ "$cur" != "$maj" ]; then
            print_warning "PostgreSQL major: установлена $cur, в apt candidate major=$maj"
            if [ "$allow_major" != true ]; then
                print_error "Смена major требует явного флага: $0 db update postgresql --major"
                print_info "После бэкапа обычно нужен pg_upgrade / pg_lsclusters — см. docs PostgreSQL"
                return 1
            fi
            print_warning "Флаг --major принят: будет apt upgrade (проверьте кластеры после!)"
        fi
    fi
    
    if [ "$dry_run" = true ]; then
        print_info "[dry-run] бэкап → stop $unit → apt --only-upgrade $pkgs → start → smoke"
        return 0
    fi
    
    if [ "$name" = "mariadb" ] || [ "$name" = "postgresql" ] || [ "$name" = "redis" ]; then
        if [ "$no_backup" = true ]; then
            print_warning "Бэкап пропущен (--no-backup)"
        else
            db_backup "$name" || {
                print_error "Бэкап не удался. Прервано. Используйте --no-backup чтобы форсировать."
                return 1
            }
        fi
    fi
    
    print_info "Остановка $unit..."
    sudo systemctl stop "$unit" 2>/dev/null || true
    
    sudo apt-get update
    # shellcheck disable=SC2086
    if ! sudo DEBIAN_FRONTEND=noninteractive apt-get install --only-upgrade -y $pkgs; then
        print_warning "apt upgrade $name завершился с ошибкой — пробуем start"
        sudo systemctl start "$unit" 2>/dev/null || true
        return 1
    fi
    
    print_info "Запуск $unit..."
    sudo systemctl start "$unit" 2>/dev/null || true
    sleep 1
    db_smoke_check "$name" || true
    state_set "DB_LAST_UPDATE_${name}" "$(date -Iseconds)"
    print_success "$name обновлён"
}

cmd_db() {
    local sub="${1:-}"
    shift || true
    
    case "$sub" in
        ""|help|--help|-h)
            show_db_help
            return 0
            ;;
        status)
            db_status
            return 0
            ;;
        update)
            local dry_run=false
            local no_backup=false
            local allow_major=false
            local targets=()
            local arg norm
            for arg in "$@"; do
                case "$arg" in
                    --dry-run) dry_run=true ;;
                    --no-backup) no_backup=true ;;
                    --major) allow_major=true ;;
                    *)
                        norm=$(db_normalize_name "$arg")
                        if [ -z "$norm" ]; then
                            print_error "Неизвестная БД/флаг: $arg"
                            show_db_help
                            return 1
                        fi
                        targets+=("$norm")
                        ;;
                esac
            done
            if [ ${#targets[@]} -eq 0 ]; then
                targets=(mariadb postgresql redis memcached)
            fi
            if [ "$dry_run" != true ]; then
                run_prechecks
            fi
            local t
            local failed=0
            for t in "${targets[@]}"; do
                if ! db_update_one "$t" "$dry_run" "$no_backup" "$allow_major"; then
                    failed=1
                fi
            done
            return "$failed"
            ;;
        *)
            print_error "Неизвестная команда db: $sub"
            show_db_help
            return 1
            ;;
    esac
}

