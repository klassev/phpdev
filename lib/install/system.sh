# lib/install/system.sh — auto-split from setup-dev-env.sh
# shellcheck shell=bash

update_system() {
    print_section "Обновление системы"
    
    sudo apt update
    sudo apt upgrade -y
    
    # Обновление snap пакетов
    # Если snap-store блокирует обновление, завершаем его процесс
    if pgrep -x "snap-store" > /dev/null; then
        print_warning "snap-store запущен, закрываем для обновления..."
        pkill snap-store || true
        sleep 2
    fi
    
    sudo snap refresh || print_warning "Не удалось обновить snap пакеты"
    
    print_success "Система обновлена"
}

install_base_packages() {
    print_section "Установка базовых пакетов"
    
    # Исправление возможных сломанных пакетов перед установкой
    sudo apt --fix-broken install -y || true
    
    # Основные утилиты (без libdvd-pkg — он устанавливается отдельно)
    sudo apt install -y \
        aptitude \
        gedit \
        mc \
        nano \
        rar \
        unrar \
        htop \
        git \
        openssh-server \
        openssh-client \
        libavcodec-extra \
        gscan2pdf \
        synaptic \
        gdebi \
        dconf-editor \
        p7zip-rar \
        arj \
        gnome-shell-extensions \
        libreoffice \
        transmission \
        vlc \
        gimp \
        neofetch \
        curl \
        wget \
        fonts-powerline
    
    # Сетевые инструменты и расширения GNOME
    sudo apt install -y \
        network-manager-openconnect \
        network-manager-openconnect-gnome \
        bashtop \
        chrome-gnome-shell \
        gnome-shell-extension-manager \
        gcc \
        libtool \
        libssl-dev \
        libc-dev \
        libjpeg-turbo8-dev \
        libpng-dev \
        libtiff5-dev \
        cups \
        printer-driver-gutenprint \
        gnome-tweaks
    
    # Установка libdvd-pkg отдельно (требует интерактивной настройки)
    print_info "Установка libdvd-pkg (для воспроизведения DVD)..."
    # Предварительно принимаем лицензию
    echo "libdvd-pkg libdvd-pkg/first-install note" | sudo debconf-set-selections
    echo "libdvd-pkg libdvd-pkg/post-invoke_hook-install boolean true" | sudo debconf-set-selections
    
    if sudo DEBIAN_FRONTEND=noninteractive apt install -y libdvd-pkg; then
        sudo DEBIAN_FRONTEND=noninteractive dpkg-reconfigure libdvd-pkg || true
        print_success "libdvd-pkg установлен"
    else
        print_warning "libdvd-pkg не удалось установить автоматически"
        print_info "Установите вручную позже: sudo apt install libdvd-pkg && sudo dpkg-reconfigure libdvd-pkg"
    fi
    
    # Финальное исправление зависимостей
    sudo apt --fix-broken install -y || true
    
    print_success "Базовые пакеты установлены"
}

install_zsh() {
    print_section "Установка ZSH и Oh My Zsh"
    
    # Установка ZSH
    sudo apt install -y zsh
    
    # Установка Oh My Zsh (неинтерактивно)
    if [ ! -d "$HOME_DIR/.oh-my-zsh" ]; then
        print_info "Установка Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    else
        print_warning "Oh My Zsh уже установлен"
    fi
    
    # Установка Powerlevel10k
    if [ ! -d "$HOME_DIR/powerlevel10k" ]; then
        print_info "Установка Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME_DIR/powerlevel10k"
    fi
    
    # Добавление темы в .zshrc если её там ещё нет
    if ! grep -q "powerlevel10k.zsh-theme" "$HOME_DIR/.zshrc" 2>/dev/null; then
        echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' >> "$HOME_DIR/.zshrc"
    fi
    
    # Установка плагинов для ZSH
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME_DIR/.oh-my-zsh/custom}"
    
    # Autosuggestions
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    fi
    
    # Syntax highlighting
    if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    fi
    
    # Обновление плагинов в .zshrc
    if grep -q "^plugins=" "$HOME_DIR/.zshrc"; then
        sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME_DIR/.zshrc"
    fi
    
    # Смена shell на ZSH
    if [ "$SHELL" != "/usr/bin/zsh" ]; then
        print_info "Смена shell на ZSH..."
        chsh -s $(which zsh)
    fi
    
    print_success "ZSH установлен и настроен"
    print_warning "Для настройки Powerlevel10k перезапустите терминал"
    print_info "Скачайте шрифты Meslo Nerd Font: https://github.com/romkatv/powerlevel10k#meslo-nerd-font-patched-for-powerlevel10k"
}

create_directories() {
    print_section "Создание рабочих директорий"
    
    mkdir -p "$WWW_DIR"
    mkdir -p "$BACKUP_DIR"
    
    print_success "Директория $WWW_DIR создана"
    print_success "Директория $BACKUP_DIR создана"
}

configure_git() {
    print_section "Настройка Git"
    
    # Использование параметров собранных в начале или запрос новых
    local git_name="$USER_GIT_NAME"
    local git_email="$USER_GIT_EMAIL"
    
    # Если параметры не были собраны, запросить
    if [ -z "$git_name" ]; then
        local current_name=$(git config --global user.name 2>/dev/null || echo "")
        if [ -z "$current_name" ]; then
            read -p "Введите ваше имя для Git: " git_name
        else
            git_name="$current_name"
            print_info "Git user.name уже настроен: $current_name"
        fi
    fi
    
    if [ -z "$git_email" ]; then
        local current_email=$(git config --global user.email 2>/dev/null || echo "")
        if [ -z "$current_email" ]; then
            read -p "Введите ваш email для Git: " git_email
        else
            git_email="$current_email"
            print_info "Git user.email уже настроен: $current_email"
        fi
    fi
    
    # Применение настроек
    if [ -n "$git_name" ]; then
        git config --global user.name "$git_name"
        print_success "Git user.name: $git_name"
    fi
    
    if [ -n "$git_email" ]; then
        git config --global user.email "$git_email"
        print_success "Git user.email: $git_email"
    fi
    
    # Полезные алиасы
    git config --global alias.st "status"
    git config --global alias.co "checkout"
    git config --global alias.br "branch"
    git config --global alias.ci "commit"
    git config --global alias.unstage "reset HEAD --"
    git config --global alias.last "log -1 HEAD"
    git config --global alias.lg "log --oneline --graph --decorate --all"
    git config --global alias.df "diff"
    git config --global alias.dfs "diff --staged"
    
    # Настройки
    git config --global init.defaultBranch "main"
    git config --global core.autocrlf "input"
    git config --global pull.rebase "false"
    git config --global push.autoSetupRemote "true"
    
    print_success "Git алиасы настроены: st, co, br, ci, lg, df, dfs"
    
    add_recommendation "Используйте git lg для красивого лога коммитов"
}

generate_ssh_keys() {
    print_section "Генерация SSH ключей"
    
    local ssh_dir="$HOME_DIR/.ssh"
    local ssh_key="$ssh_dir/id_ed25519"
    
    # Проверка существующего ключа
    if [ -f "$ssh_key" ]; then
        # Если параметр собран в начале — использовать его
        if [ "$GENERATE_NEW_SSH" = false ]; then
            print_info "Используется существующий SSH ключ"
            add_recommendation "Добавьте SSH ключ в GitHub/GitLab: cat ~/.ssh/id_ed25519.pub"
            return 0
        elif [ "$GENERATE_NEW_SSH" != true ]; then
            # Если не было сбора параметров — спросить
            print_warning "SSH ключ уже существует: $ssh_key"
            read -p "Создать новый ключ? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Используется существующий ключ"
                add_recommendation "Добавьте SSH ключ в GitHub/GitLab: cat ~/.ssh/id_ed25519.pub"
                return 0
            fi
        fi
        # Бэкап существующего ключа
        backup_config "$ssh_key"
        backup_config "$ssh_key.pub"
    fi
    
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Получение email для ключа (из собранных параметров или git config)
    local email="$USER_GIT_EMAIL"
    if [ -z "$email" ]; then
        email=$(git config --global user.email 2>/dev/null || echo "")
    fi
    if [ -z "$email" ]; then
        read -p "Введите email для SSH ключа: " email
    fi
    
    # Генерация ключа ED25519 (более безопасный чем RSA)
    ssh-keygen -t ed25519 -C "$email" -f "$ssh_key" -N ""
    
    # Запуск ssh-agent и добавление ключа
    eval "$(ssh-agent -s)" &>/dev/null
    ssh-add "$ssh_key" 2>/dev/null
    
    # Настройка SSH config
    local ssh_config="$ssh_dir/config"
    if [ ! -f "$ssh_config" ]; then
        cat > "$ssh_config" << 'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes

Host bitbucket.org
    HostName bitbucket.org
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes

Host gitlab.com
    HostName gitlab.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    AddKeysToAgent yes
EOF
        chmod 600 "$ssh_config"
        print_success "SSH config создан"
    fi
    
    print_success "SSH ключ сгенерирован"
    
    # Копирование в буфер обмена если есть xclip
    if command -v xclip &>/dev/null; then
        cat "$ssh_key.pub" | xclip -selection clipboard 2>/dev/null
        print_info "Ключ скопирован в буфер обмена"
    fi
    
    add_recommendation "Добавьте SSH ключ в GitHub/GitLab/Bitbucket"
}

