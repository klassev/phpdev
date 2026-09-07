# lib/install/web.sh — auto-split from setup-dev-env.sh
# shellcheck shell=bash

install_apache() {
    print_section "Установка Apache2"
    
    if ! is_command_exists apache2; then
        sudo apt install -y apache2 libapache2-mpm-itk
    else
        print_warning "Apache2 уже установлен: $(apache2 -v | head -1)"
        print_info "Обновляем порты и модули..."
    fi
    
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
    
    # Обновление default sites для новых портов
    if [ -f /etc/apache2/sites-available/000-default.conf ]; then
        sudo sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-available/000-default.conf
    fi
    if [ -f /etc/apache2/sites-available/default-ssl.conf ]; then
        sudo sed -i 's/<VirtualHost \*:443>/<VirtualHost *:8443>/' /etc/apache2/sites-available/default-ssl.conf
        sudo sed -i 's/<VirtualHost _default_:\*:443>/<VirtualHost _default_:8443>/' /etc/apache2/sites-available/default-ssl.conf
    fi
    
    # Отключение автозапуска
    sudo systemctl disable apache2.service 2>/dev/null || true
    
    print_success "Apache2 установлен"
    print_info "Порты Apache: HTTP=8080, HTTPS=8443"
    print_info "Порты Nginx: HTTP=80, HTTPS=443"
    print_info "Для запуска: sudo systemctl start apache2"
}

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

