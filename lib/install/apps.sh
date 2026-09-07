# lib/install/apps.sh — auto-split from setup-dev-env.sh
# shellcheck shell=bash

install_apps() {
    print_section "Установка приложений"
    
    cd /tmp || true
    
    # --- VS Code ---
    print_info "Установка VS Code..."
    if ! is_command_exists code; then
        if wget -qO- https://packages.microsoft.com/keys/microsoft.asc 2>/dev/null | gpg --dearmor > packages.microsoft.gpg \
            && sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg \
            && echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
                | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null \
            && sudo apt-get update \
            && apt_install code; then
            print_success "VS Code установлен"
        else
            print_warning "Не удалось установить VS Code"
            FAILED_DOWNLOADS+=("VS Code — https://code.visualstudio.com/")
        fi
        rm -f packages.microsoft.gpg
    else
        print_warning "VS Code уже установлен"
    fi
    
    # --- Google Chrome ---
    print_info "Установка Google Chrome..."
    if ! is_command_exists google-chrome; then
        print_info "Скачивание Google Chrome .deb..."
        if download_file "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
            "chrome.deb" "Google Chrome — https://www.google.com/chrome/"; then
            if apt_install ./chrome.deb; then
                print_success "Google Chrome установлен"
            else
                FAILED_DOWNLOADS+=("Google Chrome (установка .deb)")
            fi
            rm -f chrome.deb
        fi
    else
        print_warning "Google Chrome уже установлен"
    fi
    
    # --- Cursor ---
    print_info "Установка Cursor..."
    if ! is_command_exists cursor && [ ! -f /usr/bin/cursor ]; then
        local cursor_url="https://downloader.cursor.sh/linux/deb/x64"
        print_info "Скачивание Cursor .deb (это может занять несколько минут)..."
        if download_file "$cursor_url" "cursor.deb" "Cursor — https://cursor.com/downloads"; then
            if sudo dpkg -i cursor.deb || sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y; then
                print_success "Cursor установлен"
            else
                print_warning "Не удалось установить Cursor из .deb"
                FAILED_DOWNLOADS+=("Cursor (установка .deb)")
            fi
            rm -f cursor.deb
        fi
    else
        print_warning "Cursor уже установлен"
    fi
    
    # --- Obsidian ---
    print_info "Установка Obsidian..."
    if ! is_command_exists obsidian && ! dpkg -l | grep -q obsidian; then
        print_info "Скачивание Obsidian ${OBSIDIAN_VERSION} .deb..."
        if download_file \
            "https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/obsidian_${OBSIDIAN_VERSION}_amd64.deb" \
            "obsidian.deb" "Obsidian — https://obsidian.md/download"; then
            if apt_install ./obsidian.deb; then
                print_success "Obsidian установлен"
            else
                FAILED_DOWNLOADS+=("Obsidian (установка .deb)")
            fi
            rm -f obsidian.deb
        fi
    else
        print_warning "Obsidian уже установлен"
    fi
    
    # --- Thunderbird ---
    print_info "Установка Thunderbird..."
    if ! is_command_exists thunderbird; then
        if apt_install thunderbird; then
            print_success "Thunderbird установлен"
        else
            FAILED_DOWNLOADS+=("Thunderbird (apt)")
        fi
    else
        print_warning "Thunderbird уже установлен"
    fi
    
    # --- FileZilla ---
    print_info "Установка FileZilla..."
    if ! is_command_exists filezilla; then
        if apt_install filezilla; then
            print_success "FileZilla установлен"
        else
            FAILED_DOWNLOADS+=("FileZilla (apt)")
        fi
    else
        print_warning "FileZilla уже установлен"
    fi
    
    # --- PhpStorm ---
    print_info "Установка PhpStorm..."
    if [ ! -d "/opt/phpstorm" ]; then
        print_info "Скачивание PhpStorm ${PHPSTORM_VERSION} (это может занять время)..."
        if download_file "$PHPSTORM_URL" "phpstorm.tar.gz" \
            "PhpStorm — https://www.jetbrains.com/phpstorm/download/"; then
            if sudo tar -xzf phpstorm.tar.gz -C /opt \
                && sudo mv /opt/PhpStorm-* /opt/phpstorm \
                && sudo chown -R root:root /opt/phpstorm; then
                sudo ln -sf /opt/phpstorm/bin/phpstorm.sh /usr/local/bin/phpstorm
                sudo tee /usr/share/applications/phpstorm.desktop > /dev/null << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=PhpStorm
Comment=PHP IDE
Exec=/opt/phpstorm/bin/phpstorm.sh %f
Icon=/opt/phpstorm/bin/phpstorm.png
Terminal=false
Categories=Development;IDE;
StartupWMClass=jetbrains-phpstorm
EOF
                sudo update-desktop-database || true
                print_success "PhpStorm установлен в /opt/phpstorm"
                print_info "Запуск: phpstorm или через меню приложений"
                add_recommendation "Активируйте PhpStorm лицензией JetBrains (или trial)"
            else
                print_warning "Не удалось распаковать PhpStorm"
                FAILED_DOWNLOADS+=("PhpStorm (распаковка)")
            fi
            rm -f phpstorm.tar.gz
        fi
    else
        print_warning "PhpStorm уже установлен в /opt/phpstorm"
    fi
    
    # --- DBViewer ---
    print_info "Установка DBViewer..."
    if ! is_command_exists dbviewer && ! dpkg -l | grep -q dbviewer; then
        print_info "Скачивание DBViewer .deb..."
        local dbv_ok=false
        if download_file \
            "https://github.com/DBViewer/dbviewer/releases/latest/download/dbviewer_amd64.deb" \
            "dbviewer.deb" "DBViewer — https://github.com/DBViewer/dbviewer/releases"; then
            dbv_ok=true
        else
            # Убрать запись о первой неудаче, если запасной URL сработает
            unset 'FAILED_DOWNLOADS[-1]' 2>/dev/null || true
            if download_file \
                "https://github.com/DBViewer/dbviewer/releases/download/v1.0.0/dbviewer_amd64.deb" \
                "dbviewer.deb" "DBViewer — https://github.com/DBViewer/dbviewer/releases"; then
                dbv_ok=true
            fi
        fi
        if [ "$dbv_ok" = true ]; then
            if apt_install ./dbviewer.deb; then
                print_success "DBViewer установлен"
            else
                FAILED_DOWNLOADS+=("DBViewer (установка .deb)")
            fi
            rm -f dbviewer.deb
        fi
    else
        print_warning "DBViewer уже установлен"
    fi
    
    cd - > /dev/null || true
    
    print_success "Установка приложений завершена (см. предупреждения выше при сбоях)"
    return 0
}

install_extras() {
    print_section "Установка дополнительного софта"
    
    print_info "Установка Papirus icon theme..."
    if sudo add-apt-repository -y ppa:papirus/papirus \
        && sudo apt-get update \
        && apt_install papirus-icon-theme; then
        print_success "Дополнительный софт установлен"
        return 0
    fi
    
    print_warning "Не удалось установить Papirus icon theme"
    FAILED_DOWNLOADS+=("Papirus icon theme (PPA)")
    return 1
}

