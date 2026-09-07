# lib/cli.sh — auto-split from setup-dev-env.sh
# shellcheck shell=bash

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
    echo "  php              - Установить PHP 8.1–8.4"
    echo "  php8.1|php8.2|php8.3|php8.4 - Конкретная версия (+ FPM)"
    echo "  php7.3|php7.4    - Legacy best-effort (обычно недоступны на 24.04; лучше Docker)"
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
    echo "  mailpit          - Установить Mailpit (по умолчанию)"
    echo "  mailhog          - Установить MailHog (legacy)"
    echo "  mail-service     - systemd для MAIL_CATCHER (mailpit|mailhog)"
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
    echo "  mailhog-service  - systemd MailHog (legacy)"
    echo "  mailpit-service  - systemd Mailpit"
    echo "  new-project      - Установить скрипт 'new-project'"
    echo "  vhost-script     - Установить скрипт 'vhost' для управления виртуальными хостами"
    echo "  test-hosts       - Создать тестовые хосты (Apache+PHP8.4, Nginx+PHP8.4)"
    echo "  templates        - Создать шаблоны VirtualHost"
    echo "  scripts          - Установить все скрипты (dev, new-project, vhost)"
    echo ""
    echo -e "${YELLOW}Приложения:${NC}"
    echo "  apps             - VS Code, Chrome, Cursor, Obsidian, Thunderbird, FileZilla, PhpStorm"
    echo ""
    echo -e "${YELLOW}Языки:${NC}"
    echo "  lang …           - list|add|update|default|remove (см. $0 lang help)"
    echo ""
    echo -e "${YELLOW}БД / кэш:${NC}"
    echo "  db …             - status|update (см. $0 db help)"
    echo ""
    echo -e "${YELLOW}Профили:${NC}"
    echo "  profile [name]   - minimal|web|full|desktop (см. $0 profile list)"
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
    echo "  $0 all                - Полная установка (с вводом параметров)"
    echo "  $0 all --no-input     - Полная установка без вопросов"
    echo "  $0 apache php8.2      - Apache + PHP 8.2"
    echo "  $0 php composer       - Все версии PHP и Composer"
    echo "  $0 menu               - Запустить интерактивное меню"
    echo ""
    echo "  $0 lang add php 8.5  - Добавить PHP 8.5"
    echo "  $0 lang update go    - Обновить Go"
    echo "  $0 lang list         - Список версий языков"
    echo "  $0 db status         - Статус БД"
    echo "  $0 db update         - Обновить БД (с бэкапом)"
    echo "  $0 profile web       - Профиль web-стека"
    echo ""
    echo -e "${BLUE}После установки:${NC}"
    echo "  dev start           - Запустить все сервисы"
    echo "  dev status          - Показать статус сервисов"
    echo "  new-project site.test - Создать новый проект"
    echo "  vhost list          - Показать все виртуальные хосты"
    echo "  vhost edit apache mysite.test - Редактировать виртуальный хост"
}

run_full_install() {
    update_system
    install_base_packages
    install_zsh
    create_directories
    install_apache
    install_php
    configure_php_fpm
    configure_xdebug
    install_mkcert
    run_optional "Go" install_go
    run_optional "mail catcher ($MAIL_CATCHER)" install_mail_catcher
    configure_php_mail || true
    install_mariadb
    install_postgresql
    install_redis
    install_memcached
    install_nginx
    install_composer
    run_optional "Symfony CLI" install_symfony
    run_optional "NVM" install_nvm
    run_optional "Laravel Installer" install_laravel
    install_docker
    run_optional "extras (Papirus)" install_extras
    run_optional "desktop apps" install_apps
    if is_command_exists mkcert; then
        mkcert -install || print_warning "mkcert -install не удался"
    fi
    configure_git
    generate_ssh_keys
    create_dev_script
    create_new_project_script
    create_vhost_script
    run_optional "mail systemd" create_mail_service
    run_optional "Meslo fonts" install_meslo_fonts
    create_test_hosts
    create_apache_vhost_template
    create_nginx_vhost_template
}

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
        echo -e "${GREEN}║${NC}   6)  PHP (все версии)     7)  Настроить PHP-FPM               ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   8)  Apache + PHP (default)  9)  PHP (default из versions.env) ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}БАЗЫ ДАННЫХ И КЭШ:${NC}                                            ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  10)  MariaDB             11)  PostgreSQL                      ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  12)  Redis               13)  Memcached                       ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}ИНСТРУМЕНТЫ:${NC}                                                  ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  14)  Composer + Laravel + Symfony                             ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  15)  NVM (Node.js)       16)  Docker                          ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  17)  Go + Mailpit        18)  ZSH + Oh My Zsh                 ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}НАСТРОЙКА:${NC}                                                    ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  19)  Настроить Git       20)  SSH ключи                       ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  21)  Скрипты (dev, new-project, vhost)                        ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  22)  Шрифты Meslo Nerd Font                                   ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}ПРИЛОЖЕНИЯ:${NC}                                                   ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  23)  VS Code, Chrome, Cursor, Obsidian, PhpStorm и др.        ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  ${CYAN}УТИЛИТЫ:${NC}                                                      ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  24)  Health Check (проверка окружения)                        ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  25)  Экспорт конфигурации                                     ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  26)  Импорт конфигурации                                      ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  27)  Языки: list                                              ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  28)  Языки: update PHP          29)  Языки: update Go         ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  30)  БД: status                 31)  БД: update (все)         ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}  32)  Профили (list)                                           ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   0)  Выход                                                    ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        local choice=""
        read -r -p "Выберите опцию [0-32]: " choice || true
        
        case $choice in
            1)  run_prechecks && collect_user_input && run_full_install && show_final_summary
                ;;
            2)  run_prechecks && update_system ;;
            3)  run_prechecks && install_base_packages ;;
            4)  run_prechecks && install_apache ;;
            5)  run_prechecks && install_nginx ;;
            6)  run_prechecks && install_php && configure_php_fpm ;;
            7)  configure_php_fpm ;;
            8)  run_prechecks && create_directories && install_apache && \
                install_php_version "$PHP_DEFAULT" && configure_php_fpm "$PHP_DEFAULT" ;;
            9)  run_prechecks && install_php_version "$PHP_DEFAULT" && configure_php_fpm "$PHP_DEFAULT" ;;
            10) run_prechecks && install_mariadb ;;
            11) run_prechecks && install_postgresql ;;
            12) run_prechecks && install_redis ;;
            13) run_prechecks && install_memcached ;;
            14) run_prechecks && install_composer && install_symfony && install_laravel ;;
            15) run_prechecks && install_nvm ;;
            16) run_prechecks && install_docker ;;
            17) run_prechecks && install_go && install_mail_catcher && create_mail_service ;;
            18) run_prechecks && install_zsh ;;
            19) configure_git ;;
            20) generate_ssh_keys ;;
            21) create_dev_script && create_new_project_script && create_vhost_script ;;
            22) install_meslo_fonts ;;
            23) run_prechecks && install_apps ;;
            24) health_check ;;
            25) export_config ;;
            26) import_config ;;
            27) lang_list ;;
            28) run_prechecks && lang_update_php ;;
            29) run_prechecks && lang_update_go ;;
            30) db_status ;;
            31) run_prechecks && cmd_db update ;;
            32) list_profiles ;;
            0)  
                print_success "До свидания!"
                exit 0 
                ;;
            *)  
                print_error "Неверный выбор"
                ;;
        esac
        
        echo ""
        read -r -p "Нажмите Enter для продолжения..." _ || true
    done
}

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
    
    if [[ "$1" == "lang" ]]; then
        shift
        cmd_lang "$@"
        exit $?
    fi
    
    if [[ "$1" == "db" ]]; then
        shift
        cmd_db "$@"
        exit $?
    fi
    
    if [[ "$1" == "profile" ]]; then
        shift
        local _pargs=()
        local _a
        for _a in "$@"; do
            case "$_a" in
                --no-input|--noinput|-y) SKIP_INPUT=true ;;
                list) list_profiles; exit 0 ;;
                *) _pargs+=("$_a") ;;
            esac
        done
        run_profile "${_pargs[0]:-}"
        exit $?
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
                run_full_install
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
                configure_php_fpm
                ;;
            php7.3|php7.4|php8.1|php8.2|php8.3|php8.4)
                install_php_version "${arg#php}"
                configure_php_fpm "${arg#php}"
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
            mailpit)
                install_mailpit
                ;;
            mailhog)
                install_mailhog
                ;;
            mailpit-service)
                create_mailpit_service
                ;;
            mailhog-service)
                create_mailhog_service
                ;;
            mail-service)
                create_mail_service
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
            vhost-script)
                create_vhost_script
                ;;
            test-hosts)
                create_test_hosts
                ;;
            scripts)
                create_dev_script
                create_new_project_script
                create_vhost_script
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
            --no-input|--noinput|-y)
                # Флаг обрабатывается выше, здесь пропускаем
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
        print_info "  vhost list       — показать все виртуальные хосты"
        print_info "  vhost edit apache/nginx <имя> — редактировать виртуальный хост"
    fi
}

