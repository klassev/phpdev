# 🚀 Setup Dev Environment для Ubuntu 24.04

Автоматизированный скрипт настройки полного dev-окружения для веб-разработки на Ubuntu 24.04.

## 📋 Что устанавливается

### Web-серверы
| Компонент | Порты | Описание |
|-----------|-------|----------|
| **Nginx** | 80, 443 | Основной web-сервер |
| **Apache2** | 8080, 8443 | Альтернативный web-сервер |

> ⚡ Apache и Nginx могут работать одновременно!

### PHP
- **PHP 8.1–8.5** — через apt (PPA ondrej/php) с PHP-FPM
- **Xdebug** — отладка для PhpStorm / Cursor
- Расширения: mysql, pgsql, redis, memcached, gd, curl, mbstring, xml, zip и др.

| Версия | PHP-FPM порт | Статус |
|--------|--------------|--------|
| PHP 8.1 | 9081 | Security fixes до ноября 2025 |
| PHP 8.2 | 9082 | Активная поддержка |
| PHP 8.3 | 9083 | Активная поддержка |
| PHP 8.4 | 9084 | Активная поддержка |
| PHP 8.5 | 9085 | Активная поддержка |

> **Политика PHP 7.x:** на Ubuntu 24.04 пакеты PHP 7.3/7.4 через apt обычно **недоступны**. Команды `php7.3` / `php7.4` — best-effort; для legacy-проектов используйте **Docker**. Шаблон Compose появится в этапе 7 плана улучшений.

### Базы данных и кэш
- **MariaDB** — MySQL-совместимая БД
- **PostgreSQL** — продвинутая реляционная БД
- **Redis** — кэш и очереди
- **Memcached** — распределённый кэш

### Инструменты разработки
- **Composer** — менеджер пакетов PHP
- **NVM** — управление версиями Node.js
- **Laravel Installer** — создание Laravel проектов
- **Symfony CLI** — инструменты Symfony
- **Go** — язык программирования
- **Docker** — контейнеризация
- **mkcert** — локальные SSL сертификаты (CA автоматически устанавливается после установки всех программ)
- **Mailpit** — перехват email (SMTP 1025, UI 8025); MailHog — legacy через `MAIL_CATCHER=mailhog`

### Приложения
- **VS Code** — редактор кода
- **Cursor** — AI редактор
- **PhpStorm** — PHP IDE (в /opt/phpstorm)
- **Google Chrome** — браузер
- **Obsidian** — заметки
- **Thunderbird** — почтовый клиент
- **FileZilla** — FTP клиент
- **DBViewer** — просмотрщик баз данных

### Терминал
- **ZSH** — современный shell
- **Oh My Zsh** — фреймворк для ZSH
- **Powerlevel10k** — красивая тема
- **Шрифты Meslo Nerd Font** — иконки в терминале
- Плагины: autosuggestions, syntax-highlighting

---

## 🚀 Быстрый старт

```bash
# Скачать скрипт
git clone <repo> && cd <repo>

# Сделать исполняемым
chmod +x setup-dev-env.sh

# Запустить полную установку
./setup-dev-env.sh all

# Или интерактивное меню
./setup-dev-env.sh
```

---

## 📖 Использование

### Основные команды

```bash
./setup-dev-env.sh all              # Полная установка (с вводом параметров)
./setup-dev-env.sh all --no-input   # Полная установка без вопросов
./setup-dev-env.sh menu             # Интерактивное меню
./setup-dev-env.sh help             # Справка
```

### Установка отдельных компонентов

```bash
# Web-серверы
./setup-dev-env.sh apache
./setup-dev-env.sh nginx

# PHP
./setup-dev-env.sh php              # PHP из PHP_SUPPORTED (в т.ч. 8.5)
./setup-dev-env.sh php8.5           # Только PHP 8.5 (+ FPM)
./setup-dev-env.sh php8.2           # Только PHP 8.2 (+ настройка FPM)
./setup-dev-env.sh php8.4           # Только PHP 8.4
./setup-dev-env.sh apache php8.2    # Apache + PHP 8.2
./setup-dev-env.sh php-fpm          # Настройка PHP-FPM
./setup-dev-env.sh xdebug           # Настройка Xdebug
# php7.3 / php7.4 — обычно недоступны на 24.04; для legacy — Docker

# Базы данных
./setup-dev-env.sh mariadb
./setup-dev-env.sh postgresql
./setup-dev-env.sh redis
./setup-dev-env.sh memcached

# Инструменты
./setup-dev-env.sh composer
./setup-dev-env.sh nvm
./setup-dev-env.sh laravel
./setup-dev-env.sh symfony
./setup-dev-env.sh docker
./setup-dev-env.sh go
./setup-dev-env.sh mailpit
./setup-dev-env.sh mailhog          # legacy

# Приложения
./setup-dev-env.sh apps             # VS Code, Chrome, Cursor, PhpStorm и др.

# Настройка
./setup-dev-env.sh git              # Настройка Git
./setup-dev-env.sh ssh              # Генерация SSH ключей
./setup-dev-env.sh scripts          # Установка dev, new-project и vhost
./setup-dev-env.sh vhost-script     # Установка только vhost
./setup-dev-env.sh fonts            # Шрифты Meslo Nerd Font
./setup-dev-env.sh test-hosts       # Тестовые хосты
./setup-dev-env.sh templates        # Шаблоны VirtualHost
```

### Утилиты

```bash
./setup-dev-env.sh health           # Проверка окружения
./setup-dev-env.sh export           # Экспорт конфигурации
./setup-dev-env.sh import           # Импорт конфигурации
./setup-dev-env.sh backups          # Список бэкапов
```

---

## 🛠 Скрипты после установки

> ⚡ Все скрипты (`dev`, `new-project`, `vhost`) устанавливаются автоматически при полной установке или через команду `./setup-dev-env.sh scripts`

Исходники лежат в репозитории и копируются в `/usr/local/bin`:

| Утилита | Исходник | Куда ставится |
|---------|----------|---------------|
| `dev` | `scripts/dev` | `/usr/local/bin/dev` |
| `new-project` | `scripts/new-project` | `/usr/local/bin/new-project` |
| `vhost` | `scripts/vhost` | `/usr/local/bin/vhost` |

Шаблоны VirtualHost:

| Шаблон | Исходник | Копия в `$HOME` |
|--------|----------|-----------------|
| Apache | `templates/apache/vhost.conf` | `~/vhost-template-apache.conf` |
| Nginx | `templates/nginx/vhost.conf` | `~/vhost-template-nginx.conf` |

Правки утилит делайте в `scripts/` / `templates/`, затем снова запустите `./setup-dev-env.sh scripts` или `templates`.

### Версии компонентов

Список PHP, Go, NVM, Obsidian, PhpStorm задаётся в [`config/versions.env`](config/versions.env).  
После установки фактические версии пишутся в `~/.config/phpdev/installed.env`.

Чтобы добавить новую поддерживаемую версию PHP в полную установку — допишите её в `PHP_SUPPORTED` в `versions.env` (пакет должен быть в PPA ondrej/php).

Или установите точечно без правки конфига:

```bash
./setup-dev-env.sh lang list
./setup-dev-env.sh lang add php 8.5
./setup-dev-env.sh lang update php
./setup-dev-env.sh lang update go
./setup-dev-env.sh lang add node 22
./setup-dev-env.sh lang default php 8.4
./setup-dev-env.sh lang remove php 8.1
```

### Базы данных: обновление

```bash
./setup-dev-env.sh db status
./setup-dev-env.sh db update                  # все установленные
./setup-dev-env.sh db update mariadb
./setup-dev-env.sh db update --dry-run
./setup-dev-env.sh db update postgresql --major   # смена major
./setup-dev-env.sh db update redis --no-backup    # без бэкапа (осторожно)

# алиас после установки scripts:
dev db-update mariadb
```

Перед обновлением MariaDB/PostgreSQL/Redis создаётся бэкап в `~/.config-backups/db/`.  
Смена major PostgreSQL без `--major` блокируется.

### `dev` — управление сервисами

```bash
dev start              # Запустить все сервисы
dev stop               # Остановить все сервисы
dev restart            # Перезапустить все сервисы
dev status             # Статус всех сервисов

dev web                # Только web (Apache/Nginx + PHP-FPM)
dev db                 # Только БД (MariaDB + PostgreSQL)
dev cache              # Только кэш (Redis + Memcached)

dev php 8.2            # Переключить PHP CLI на версию 8.2
dev php 8.4            # Переключить PHP CLI на версию 8.4
```

### `new-project` — создание проекта

```bash
new-project site.test                        # Базовый проект (Nginx + PHP 8.2)
new-project site.test --php=8.4              # С PHP 8.4
new-project site.test --php=8.1              # С PHP 8.1
new-project site.test --server=apache        # С Apache
new-project site.test --type=laravel         # Laravel проект
new-project site.test --type=symfony         # Symfony проект
new-project site.test --no-ssl               # Без SSL
```

Автоматически создаёт:
- Директорию проекта в `~/www/`
- SSL сертификат (mkcert)
- Конфиг Nginx или Apache
- Запись в `/etc/hosts`

### `vhost` — управление виртуальными хостами

```bash
# Просмотр списка виртуальных хостов
vhost list                    # Все виртуальные хосты
vhost list apache             # Только Apache
vhost list nginx              # Только Nginx

# Редактирование виртуальных хостов
vhost edit apache mysite.test    # Редактировать Apache виртуальный хост
vhost edit nginx mysite.test     # Редактировать Nginx виртуальный хост

# Просмотр конфигурации
vhost show apache mysite.test    # Показать конфигурацию Apache
vhost show nginx mysite.test     # Показать конфигурацию Nginx

# Включение/отключение виртуальных хостов
vhost enable apache mysite       # Включить Apache виртуальный хост
vhost enable nginx mysite        # Включить Nginx виртуальный хост
vhost disable apache mysite      # Отключить Apache виртуальный хост
vhost disable nginx mysite       # Отключить Nginx виртуальный хост

# Удаление виртуальных хостов
vhost delete apache mysite       # Удалить Apache виртуальный хост
vhost delete nginx mysite        # Удалить Nginx виртуальный хост
```

> 💡 **Совет:** Редактор по умолчанию — `nano`. Для изменения используйте переменную окружения: `export EDITOR=vim`

После редактирования конфигурации скрипт автоматически:
- Проверяет корректность конфигурации
- Предлагает перезагрузить сервер

---

## 🌐 Тестовые хосты

После установки доступны тестовые хосты:

| Хост | Сервер | PHP | URL |
|------|--------|-----|-----|
| test-apache.test | Apache | 8.4 | http://test-apache.test:8080 |
| test-apache.test | Apache | 8.4 | https://test-apache.test:8443 |
| test-nginx.test | Nginx | 8.4 | http://test-nginx.test |
| test-nginx.test | Nginx | 8.4 | https://test-nginx.test |

---

## 📁 Структура директорий

```
phpdev/
├── bin/setup-dev-env             # CLI entrypoint
├── setup-dev-env.sh              # совместимость → lib/load.sh + main
├── config/versions.env
├── lib/
│   ├── load.sh                   # подключает все модули
│   ├── common.sh                 # log, prechecks, state, versions
│   ├── cli.sh                    # menu, help, main, run_full_install
│   ├── lang.sh                   # lang list|add|update|…
│   ├── db.sh                     # db status|update
│   ├── profiles.sh
│   ├── util.sh                   # health, export/import
│   └── install/
│       ├── system.sh             # apt base, zsh, git, ssh
│       ├── web.sh                # apache, nginx
│       ├── php.sh
│       ├── database.sh
│       ├── tools.sh              # go, nvm, docker, composer, …
│       ├── apps.sh
│       └── scripts.sh            # установка scripts/ + templates/
├── profiles/
│   ├── minimal.conf
│   ├── web.conf
│   ├── full.conf
│   └── desktop.conf
├── scripts/{dev,new-project,vhost}
├── templates/{apache,nginx}/vhost.conf
├── IMPROVEMENT_PLAN.md
├── LICENSE
└── README.md

~/
├── www/
├── .config/phpdev/installed.env
├── .config-backups/db/
└── vhost-template-*.conf
```

### Профили установки

```bash
./setup-dev-env.sh profile list
./setup-dev-env.sh profile minimal
./setup-dev-env.sh profile web --no-input
./setup-dev-env.sh profile full
./setup-dev-env.sh profile desktop
# эквивалент:
./bin/setup-dev-env profile web
```

---

## ⚙️ Конфигурация

### Порты сервисов

| Сервис | Порт |
|--------|------|
| Nginx HTTP | 80 |
| Nginx HTTPS | 443 |
| Apache HTTP | 8080 |
| Apache HTTPS | 8443 |
| MariaDB | 3306 |
| PostgreSQL | 5432 |
| Redis | 6379 |
| Memcached | 11211 |
| Mailpit / MailHog SMTP | 1025 |
| Mailpit / MailHog Web | 8025 |
| PHP 8.1 FPM | 9081 |
| PHP 8.2 FPM | 9082 |
| PHP 8.3 FPM | 9083 |
| PHP 8.4 FPM | 9084 |
| PHP 8.5 FPM | 9085 |

### Xdebug

Конфигурация Xdebug для PhpStorm:

```ini
[xdebug]
xdebug.mode=debug
xdebug.start_with_request=yes
xdebug.client_host=127.0.0.1
xdebug.client_port=9003
xdebug.idekey=PHPSTORM
```

### Git алиасы

После настройки Git доступны алиасы:

```bash
git st          # git status
git co          # git checkout
git br          # git branch
git ci          # git commit
git lg          # красивый лог
git df          # git diff
git dfs         # git diff --staged
```

---

## 🔧 После установки

### 1. Перезапустите терминал

```bash
source ~/.zshrc
```

### 2. Настройте Powerlevel10k

При первом запуске ZSH запустится мастер настройки темы.

### 3. Установите Node.js

```bash
nvm install --lts
nvm install 20
```

### 4. Настройте базы данных

```bash
# MariaDB
sudo mysql_secure_installation

# PostgreSQL
sudo -u postgres psql
ALTER USER postgres WITH ENCRYPTED PASSWORD 'ваш_пароль';
```

### 5. Добавьте SSH ключ

Скопируйте публичный ключ в GitHub/GitLab/Bitbucket:

```bash
cat ~/.ssh/id_ed25519.pub
```

### 6. Docker без sudo

Перезайдите в систему (logout/login) или:

```bash
newgrp docker
```

### 7. Проверьте окружение

```bash
./setup-dev-env.sh health
```

---

## 📧 Mailpit

По умолчанию ставится **Mailpit** (`MAIL_CATCHER=mailpit` в `config/versions.env`).

- **Web UI:** http://localhost:8025
- **SMTP:** localhost:1025

```bash
./setup-dev-env.sh mailpit
sudo systemctl start mailpit
```

Для legacy MailHog: `MAIL_CATCHER=mailhog` и `./setup-dev-env.sh mailhog`.

### Laravel `.env`

```env
MAIL_MAILER=smtp
MAIL_HOST=localhost
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
```

### Legacy PHP 7.x (Docker)

```bash
cd docker/legacy-php
docker compose up -d
# http://localhost:8074
```

Подробнее: [`docker/legacy-php/README.md`](docker/legacy-php/README.md).

### Проверки качества

```bash
./scripts/check.sh    # bash -n, smoke CLI, shellcheck
```

---

## 📝 Логирование

Все действия записываются в лог:

```bash
cat ~/setup-dev-env.log
```

Бэкапы конфигов хранятся в:

```bash
ls ~/.config-backups/
```

---

## 🔄 Экспорт/Импорт конфигурации

### Экспорт (для переноса на другую машину)

```bash
./setup-dev-env.sh export
```

Создаёт архив в `~/dev-env-export/` с:
- .zshrc, .gitconfig
- SSH config
- PHP конфиги
- Nginx/Apache конфиги
- Список пакетов

### Импорт

```bash
./setup-dev-env.sh import
```

---

## ❓ Частые проблемы

### Скрипт не запускается

```bash
chmod +x setup-dev-env.sh
./setup-dev-env.sh
# или
bash setup-dev-env.sh
```

### Не удалось скачать приложение

Если при установке не удалось скачать какое-то приложение (Cursor, Obsidian, PhpStorm и др.), в конце скрипта будет выведен список со ссылками для ручного скачивания. Можно также запустить скрипт повторно.

### Docker требует sudo

```bash
# Перезайдите в систему или:
newgrp docker

# Проверка:
docker ps
```

### Apache и Nginx конфликтуют

Они настроены на разные порты:
- Nginx: 80, 443
- Apache: 8080, 8443

### PHP-FPM не запускается

```bash
sudo systemctl status php8.4-fpm
sudo journalctl -u php8.4-fpm
```

### SSL сертификат не работает

```bash
# mkcert -install выполняется автоматически после установки всех программ
# Если нужно выполнить вручную:
mkcert -install
# Перезапустите браузер
```

---

## 📜 Лицензия

MIT — см. [LICENSE](LICENSE).

---

## 👤 Автор

klassev
