# lib/install/database.sh — auto-split from setup-dev-env.sh
# shellcheck shell=bash

install_mariadb() {
    print_section "Установка MariaDB"
    
    if is_command_exists mariadb; then
        print_warning "MariaDB уже установлен: $(mariadb --version)"
        print_info "Для обновления: $0 db update mariadb"
        return 0
    fi
    
    sudo apt install -y mariadb-server mariadb-client
    
    # Отключение автозапуска
    sudo systemctl disable mariadb.service
    
    print_success "MariaDB установлен"
    mariadb --version
    
    add_recommendation "Настройте MariaDB: sudo mysql_secure_installation"
}

install_postgresql() {
    print_section "Установка PostgreSQL"
    
    if is_command_exists psql; then
        print_warning "PostgreSQL уже установлен: $(psql --version)"
        print_info "Для обновления: $0 db update postgresql"
        return 0
    fi
    
    sudo apt install -y postgresql postgresql-client
    
    # Отключение автозапуска
    sudo systemctl disable postgresql.service
    
    print_success "PostgreSQL установлен"
    
    add_recommendation "Установите пароль PostgreSQL: sudo -u postgres psql → ALTER USER postgres WITH ENCRYPTED PASSWORD 'пароль';"
}

install_redis() {
    print_section "Установка Redis"
    
    if is_command_exists redis-server; then
        print_warning "Redis уже установлен: $(redis-server --version)"
        print_info "Для обновления: $0 db update redis"
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
    for version in "${PHP_ALL_KNOWN_VERSIONS[@]}"; do
        sudo apt install -y "php${version}-redis" 2>/dev/null || true
    done
    
    print_success "PHP расширения Redis установлены"
}

install_memcached() {
    print_section "Установка Memcached"
    
    if is_command_exists memcached; then
        print_warning "Memcached уже установлен: $(memcached -h | head -1)"
        print_info "Для обновления: $0 db update memcached"
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
    for version in "${PHP_ALL_KNOWN_VERSIONS[@]}"; do
        sudo apt install -y "php${version}-memcached" 2>/dev/null || true
    done
    
    print_success "PHP расширения Memcached установлены"
}

