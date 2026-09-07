# lib/install/scripts.sh — auto-split from setup-dev-env.sh
# shellcheck shell=bash

create_dev_script() {
    print_section "Установка скрипта управления сервисами"
    
    local src="$SCRIPT_DIR/scripts/dev"
    local dest="/usr/local/bin/dev"
    
    if [ -f "$dest" ]; then
        print_warning "Скрипт 'dev' уже существует — обновляем из репозитория"
    fi
    
    install_from_repo "$src" "$dest" 755
    print_info "Использование: dev start | stop | status | php 8.2"
}

create_new_project_script() {
    print_section "Установка скрипта создания проектов"
    
    local src="$SCRIPT_DIR/scripts/new-project"
    local dest="/usr/local/bin/new-project"
    
    if [ -f "$dest" ]; then
        print_warning "Скрипт 'new-project' уже существует — обновляем из репозитория"
    fi
    
    install_from_repo "$src" "$dest" 755
    print_info "Использование: new-project site.test [--php=8.2] [--server=nginx|apache]"
}

create_vhost_script() {
    print_section "Установка скрипта управления виртуальными хостами"
    
    local src="$SCRIPT_DIR/scripts/vhost"
    local dest="/usr/local/bin/vhost"
    
    if [ -f "$dest" ]; then
        print_warning "Скрипт 'vhost' уже существует — обновляем из репозитория"
    fi
    
    install_from_repo "$src" "$dest" 755
    print_info "Использование: vhost list | edit | show | enable | disable | delete"
}

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
    print_section "Установка шаблона Apache VirtualHost"
    
    local src="$SCRIPT_DIR/templates/apache/vhost.conf"
    local dest="$HOME_DIR/vhost-template-apache.conf"
    
    if [ ! -f "$src" ]; then
        print_error "Шаблон не найден: $src"
        return 1
    fi
    
    cp "$src" "$dest"
    print_success "Шаблон создан: $dest"
    print_info "Инструкция по созданию VirtualHost:"
    print_info "1. Создайте сертификат: mkcert site.test '*.site.test' localhost 127.0.0.1"
    print_info "2. Скопируйте сертификаты в /etc/ssl/certs и /etc/ssl/private"
    print_info "3. sudo cp $dest /etc/apache2/sites-available/site.test.conf"
    print_info "4. sudo a2ensite site.test.conf && sudo service apache2 restart"
    print_info "Исходник в репозитории: templates/apache/vhost.conf"
}

create_nginx_vhost_template() {
    print_section "Установка шаблона Nginx VirtualHost"
    
    local src="$SCRIPT_DIR/templates/nginx/vhost.conf"
    local dest="$HOME_DIR/vhost-template-nginx.conf"
    
    if [ ! -f "$src" ]; then
        print_error "Шаблон не найден: $src"
        return 1
    fi
    
    cp "$src" "$dest"
    print_success "Шаблон создан: $dest"
    print_info "Инструкция по созданию Nginx VirtualHost:"
    print_info "1. Создайте сертификат: mkcert site.test '*.site.test' localhost 127.0.0.1"
    print_info "2. Скопируйте шаблон: sudo cp $dest /etc/nginx/sites-available/site.test"
    print_info "3. sudo ln -s /etc/nginx/sites-available/site.test /etc/nginx/sites-enabled/"
    print_info "4. sudo nginx -t && sudo service nginx reload"
    print_info "Исходник в репозитории: templates/nginx/vhost.conf"
}

