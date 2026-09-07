# lib/install/tools.sh — auto-split from setup-dev-env.sh
# shellcheck shell=bash

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
    
    print_success "mkcert установлен"
    print_info "Использование: mkcert example.test '*.example.test' localhost 127.0.0.1"
    print_info "Примечание: mkcert -install будет выполнен после установки всех программ"
}

install_go() {
    local target_version="$GO_VERSION"
    local force=false
    local a
    for a in "$@"; do
        case "$a" in
            --force) force=true ;;
            *) target_version="$a" ;;
        esac
    done
    
    print_section "Установка Go $target_version"
    
    if is_command_exists go; then
        local current_version
        current_version=$(go version | awk '{print $3}' | sed 's/^go//')
        if [ "$force" != true ] && [ "$current_version" = "$target_version" ]; then
            print_warning "Go $current_version уже установлен"
            record_go_installed "$current_version"
            return 0
        fi
        if [ "$force" != true ]; then
            print_warning "Go уже установлен: $current_version (цель: $target_version)"
            print_info "Для обновления: $0 lang update go  или  lang add go $target_version"
            record_go_installed "$current_version"
            return 0
        fi
        print_info "Принудительное обновление Go $current_version → $target_version"
    fi
    
    cd /tmp || return 1
    
    print_info "Скачивание Go ${target_version}..."
    if ! download_file "https://go.dev/dl/go${target_version}.linux-amd64.tar.gz" \
        "go${target_version}.linux-amd64.tar.gz" "Go ${target_version} — https://go.dev/dl/"; then
        return 1
    fi
    
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go${target_version}.linux-amd64.tar.gz"
    rm -f "go${target_version}.linux-amd64.tar.gz"
    
    local GO_ENV="
# Go configuration
export GOROOT=/usr/local/go
export GOPATH=\$HOME/go
export PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH
"
    
    if [ -f "$HOME_DIR/.zshrc" ] && ! grep -q "GOROOT" "$HOME_DIR/.zshrc" 2>/dev/null; then
        echo "$GO_ENV" >> "$HOME_DIR/.zshrc"
    fi
    if [ -f "$HOME_DIR/.bashrc" ] && ! grep -q "GOROOT" "$HOME_DIR/.bashrc" 2>/dev/null; then
        echo "$GO_ENV" >> "$HOME_DIR/.bashrc"
    fi
    
    export GOROOT=/usr/local/go
    export GOPATH=$HOME_DIR/go
    export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
    
    print_success "Go установлен"
    /usr/local/go/bin/go version
    record_go_installed "$target_version"
}

install_mailpit() {
    print_section "Установка Mailpit ${MAILPIT_VERSION}"
    
    if is_command_exists mailpit || [ -x /usr/local/bin/mailpit ]; then
        print_warning "Mailpit уже установлен: $(mailpit version 2>/dev/null || echo /usr/local/bin/mailpit)"
        return 0
    fi
    
    cd /tmp || return 1
    local arch="amd64"
    case "$(uname -m)" in
        aarch64|arm64) arch="arm64" ;;
    esac
    local url="https://github.com/axllent/mailpit/releases/download/${MAILPIT_VERSION}/mailpit-linux-${arch}.tar.gz"
    print_info "Скачивание $url"
    if ! download_file "$url" "mailpit.tar.gz" "Mailpit ${MAILPIT_VERSION}"; then
        return 1
    fi
    tar -xzf mailpit.tar.gz
    sudo install -m 755 mailpit /usr/local/bin/mailpit
    rm -f mailpit.tar.gz mailpit
    print_success "Mailpit установлен: $(mailpit version 2>/dev/null || true)"
    print_info "Web UI: http://localhost:8025 | SMTP: localhost:1025"
}

install_mailhog() {
    print_section "Установка MailHog (legacy)"
    
    if [ -f "$HOME_DIR/go/bin/MailHog" ]; then
        print_warning "MailHog уже установлен"
        return 0
    fi
    
    if ! is_command_exists go; then
        print_error "Go не установлен. Сначала установите Go (или используйте MAIL_CATCHER=mailpit)."
        return 1
    fi
    
    export GOROOT=/usr/local/go
    export GOPATH=$HOME_DIR/go
    export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
    
    go install github.com/mailhog/MailHog@latest
    
    if ! is_command_exists mhsendmail; then
        if download_file \
            "https://github.com/mailhog/mhsendmail/releases/download/v0.2.0/mhsendmail_linux_amd64" \
            "/tmp/mhsendmail" "mhsendmail"; then
            sudo install -m 755 /tmp/mhsendmail /usr/local/bin/mhsendmail
            rm -f /tmp/mhsendmail
        fi
    fi
    
    print_success "MailHog установлен"
    print_info "Web UI: http://localhost:8025 | SMTP: localhost:1025"
}

# Установить перехватчик почты согласно MAIL_CATCHER (versions.env)
install_mail_catcher() {
    case "${MAIL_CATCHER:-mailpit}" in
        mailhog) install_mailhog ;;
        *) install_mailpit ;;
    esac
}

create_mailpit_service() {
    print_section "Создание systemd сервиса Mailpit"
    
    if ! is_command_exists mailpit && [ ! -x /usr/local/bin/mailpit ]; then
        print_error "Mailpit не установлен. Сначала: $0 mailpit"
        return 1
    fi
    
    local bin
    bin="$(command -v mailpit || echo /usr/local/bin/mailpit)"
    local service_file="/etc/systemd/system/mailpit.service"
    
    sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Mailpit Email Testing
After=network.target

[Service]
Type=simple
User=$USERNAME
ExecStart=$bin --smtp 0.0.0.0:1025 --ui 0.0.0.0:8025
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable mailpit.service
    print_success "Сервис mailpit создан и включён"
    print_info "  sudo systemctl start mailpit"
}

create_mailhog_service() {
    print_section "Создание systemd сервиса для MailHog"
    
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

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable mailhog.service
    print_success "Сервис MailHog создан и включён"
}

create_mail_service() {
    case "${MAIL_CATCHER:-mailpit}" in
        mailhog) create_mailhog_service ;;
        *) create_mailpit_service ;;
    esac
}

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

install_nvm() {
    print_section "Установка NVM ${NVM_VERSION}"
    
    if [ -d "$HOME_DIR/.nvm" ]; then
        print_warning "NVM уже установлен"
        print_info "Пропускаем установку"
        record_nvm_installed "present"
        return 0
    fi
    
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
    
    print_success "NVM установлен"
    record_nvm_installed "$NVM_VERSION"
    
    add_recommendation "Установите Node.js: nvm install --lts"
}

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

