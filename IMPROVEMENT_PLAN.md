# План улучшения phpdev

> Dev-окружение для Ubuntu 24.04: `setup-dev-env.sh` + утилиты `dev` / `new-project` / `vhost`.

## Как вести этот файл

1. Меняйте **Статус этапа** и отмечайте чекбоксы по мере работы.
2. В конце каждого шага кратко пишите результат в блок `Результат`.
3. Обновляйте **Прогресс** в шапке и дату `Обновлено`.
4. Новые идеи добавляйте в [Бэклог](#бэклог), затем переносите в этапы.

| Поле | Значение |
|------|----------|
| Обновлено | 2026-09-07 |
| Текущий этап | завершён (этапы 0–7) |
| Прогресс | 8 / 8 этапов |

Статусы этапа: `не начато` · `в работе` · `готово` · `отложено`

---

## Обзор этапов

| # | Этап | Статус | Цель |
|---|------|--------|------|
| 0 | [Подготовка и правила](#этап-0--подготовка-и-правила) | готово | Честная docs, LICENSE, политика PHP 7 |
| 1 | [Безопасность скрипта](#этап-1--безопасность-скрипта) | готово | `pipefail`, ошибки apt/wget, без падения всего `all` |
| 2 | [Вынос скриптов и шаблонов](#этап-2--вынос-скриптов-и-шаблонов) | готово | `dev` / `new-project` / `vhost` + templates как файлы |
| 3 | [Конфиг версий и реестр](#этап-3--конфиг-версий-и-реестр) | готово | Один источник правды для версий языков/софта |
| 4 | [Языки: add / update / default](#этап-4--языки-add--update--default) | готово | Добавление новых версий PHP/Go/Node без правки кода |
| 5 | [БД: update и бэкапы](#этап-5--бд-update-и-бэкапы) | готово | Обновление уже установленных БД |
| 6 | [Модули и профили](#этап-6--модули-и-профили) | готово | Разбиение монолита, профили установки |
| 7 | [CI, health, Mailpit](#этап-7--ci-health-mailpit) | готово | ShellCheck, smoke-тесты, актуальный стек |

---

## Этап 0 — подготовка и правила

**Статус:** готово  
**Зависимости:** нет

### Шаги

- [x] 0.1 Зафиксировать политику PHP 7.x: не обещать apt-установку на Ubuntu 24.04; legacy — через Docker
- [x] 0.2 Синхронизировать README и комментарии в `setup-dev-env.sh` (версии PHP, порты, EOL)
- [x] 0.3 Добавить файл `LICENSE` (MIT, как в README)
- [x] 0.4 Расширить `.gitignore` (логи, `.deb`, архивы, бэкапы, локальный state)
- [x] 0.5 Убрать / переформулировать рекомендацию ja-netfilter в установке PhpStorm

### Результат

```
- PHP: apt по умолчанию только 8.1–8.4 (PHP_SUPPORTED_VERSIONS); 7.x — warning + Docker
- README/help синхронизированы; LICENSE (MIT); .gitignore расширен
- ja-netfilter заменён на рекомендацию официальной лицензии JetBrains
```

### Заметки

```
Команды php7.3/php7.4 оставлены как best-effort для явного вызова.
Docker Compose для legacy — этап 7.5.
```

---

## Этап 1 — безопасность скрипта

**Статус:** готово  
**Зависимости:** этап 0 (желательно)

### Шаги

- [x] 1.1 Включить `set -euo pipefail` (или эквивалент с аккуратной обработкой)
- [x] 1.2 Опциональные приложения (`apps`) не должны ронять полную установку `all`
- [x] 1.3 Явная обработка ошибок `apt` / `wget` / `curl` с записью в `FAILED_DOWNLOADS`
- [x] 1.4 Убрать дублирование веток `all` (меню vs `main`) — одна функция `run_full_install`
- [x] 1.5 Один `show_help` для главного CLI (убрать дубли вложенных, где возможно)

### Результат

```
- set -euo pipefail; лог с fallback в /tmp; ((i++)) → i=$((i+1))
- Хелперы: apt_install, download_file, run_optional
- install_apps всегда return 0; extras/apps/go/mailhog/nvm… через run_optional в run_full_install
- Единая run_full_install для menu п.1 и CLI `all`
- Главный show_help один; справки util-скриптов остаются в heredoc до этапа 2
```

### Заметки

```
Вложенные show_help в DEVSCRIPT/PROJECTSCRIPT/VHOSTSCRIPT — отдельные CLI, вынесутся на этапе 2.
```

---

## Этап 2 — вынос скриптов и шаблонов

**Статус:** готово  
**Зависимости:** этап 1

### Целевая структура (черновик)

```
scripts/dev
scripts/new-project
scripts/vhost
templates/apache/*.conf
templates/nginx/*.conf
```

### Шаги

- [x] 2.1 Вынести `dev` из heredoc в `scripts/dev`
- [x] 2.2 Вынести `new-project` в `scripts/new-project`
- [x] 2.3 Вынести `vhost` в `scripts/vhost`
- [x] 2.4 Вынести шаблоны VirtualHost в `templates/`
- [x] 2.5 `create_*_script` копирует файлы из репо в `/usr/local/bin` (или `~/bin`) вместо генерации heredoc
- [x] 2.6 Обновить README: где лежат исходники утилит

### Результат

```
- scripts/{dev,new-project,vhost} + templates/{apache,nginx}/vhost.conf
- install_from_repo + create_* копируют из $SCRIPT_DIR
- setup-dev-env.sh ~2850 строк (было ~3800)
- README: таблица исходников и структура репозитория
```

### Заметки

```
create_test_hosts по-прежнему генерирует конфиги inline — можно позже перевести на templates.
```

---

## Этап 3 — конфиг версий и реестр

**Статус:** готово  
**Зависимости:** этап 2 (можно параллельно с 2 после 1)

### Целевые файлы

```
config/versions.env          # PHP_SUPPORTED, GO_VERSION, NVM_VERSION, …
~/.config/phpdev/installed.env   # что реально стоит на машине (state)
```

### Шаги

- [x] 3.1 Создать `config/versions.env` с версиями PHP, Go, NVM, mkcert, приложений
- [x] 3.2 Загрузка конфига в начале `setup-dev-env.sh` (или `bin/` обёртки)
- [x] 3.3 Заменить захардкоженные циклы `for version in 7.3 7.4 …` на `$PHP_SUPPORTED`
- [x] 3.4 State-файл: запись установленных версий PHP/Go/Node после install
- [x] 3.5 Жёсткие URL Obsidian/PhpStorm → версия из конфига или «latest» где безопасно

### Результат

```
- config/versions.env + load_versions_config()
- state: state_set / record_php|go|nvm_installed → ~/.config/phpdev/installed.env
- Obsidian/PhpStorm/NVM из конфига; меню 8/9 используют PHP_DEFAULT
- scripts/dev: PHP-FPM через glob unit-файлов, без хардкода версий
- health показывает config + state
```

### Заметки

```
NODE_INSTALLED появится на этапе 4 (lang add node).
```

---

## Этап 4 — языки: add / update / default

**Статус:** готово  
**Зависимости:** этап 3

### Целевой CLI

```bash
./setup-dev-env.sh lang list
./setup-dev-env.sh lang add php 8.5
./setup-dev-env.sh lang add go 1.27.0
./setup-dev-env.sh lang add node 22
./setup-dev-env.sh lang update php
./setup-dev-env.sh lang update go
./setup-dev-env.sh lang update node --lts
./setup-dev-env.sh lang default php 8.4
./setup-dev-env.sh lang remove php 8.1   # с подтверждением
```

### Шаги

- [x] 4.1 Каркас команды `lang` (dispatch + help)
- [x] 4.2 `lang list` — конфиг + state + фактические бинарники
- [x] 4.3 `lang add php <ver>` — пакеты, FPM-порт, xdebug, mail path, запись в state
- [x] 4.4 `lang update php` — `apt` upgrade установленных php*-пакетов
- [x] 4.5 `lang default php <ver>` — `update-alternatives` / синхронизация с `dev php`
- [x] 4.6 Go: убрать «уже установлен → skip»; `lang add/update go` заменяет `/usr/local/go`
- [x] 4.7 Node: обёртка над nvm — `lang add/update/default node`
- [x] 4.8 Пункты меню для add/update языков
- [x] 4.9 Документация в README + примеры
- [ ] 4.10 (Опционально) плагин-контракт `lib/lang/{php,go,node}.sh` для новых языков

### Критерии готовности

- [x] Новую версию PHP можно поставить командой, без правки списков в коде (версия есть в PPA)
- [x] `lang update go` обновляет Go, если целевая версия новее
- [x] `health` / `lang list` показывают установленные версии

### Результат

```
- cmd_lang + show_lang_help; PHP case 7.*|8.*
- install_go [ver] --force
- Меню 27–29; README примеры
- 4.10 отложено до этапа 6 (модули)
```

### Заметки

```
Плагин-контракт lib/lang — вместе с разбиением монолита (этап 6).
```

---

## Этап 5 — БД: update и бэкапы

**Статус:** готово  
**Зависимости:** этап 3 (бэкапы можно раньше)

### Целевой CLI

```bash
./setup-dev-env.sh db status
./setup-dev-env.sh db update
./setup-dev-env.sh db update mariadb
./setup-dev-env.sh db update postgresql
./setup-dev-env.sh db update redis
./setup-dev-env.sh db update memcached
./setup-dev-env.sh db update --dry-run
./setup-dev-env.sh db update postgresql --major   # явно, с бэкапом
```

### Шаги

- [x] 5.1 Каркас команды `db` (dispatch + help)
- [x] 5.2 `db status` — версия установленная / доступная в apt, статус сервиса
- [x] 5.3 Бэкап перед update: MariaDB dump, PostgreSQL `pg_dumpall`, Redis RDB → `~/.config-backups/db/`
- [x] 5.4 `db update <name>` — stop → apt upgrade пакетов → start → smoke-check
- [x] 5.5 Флаг `--no-backup` с предупреждением; по умолчанию бэкап обязателен для SQL-БД
- [x] 5.6 Major PostgreSQL: отдельный путь `--major` или отказ + инструкция (`pg_upgrade`)
- [x] 5.7 Убрать «уже установлен → skip» как единственное поведение; install остаётся для первой установки, update — для апгрейда
- [x] 5.8 Алиас в `dev` (например `dev db update`) — по желанию
- [x] 5.9 Документация: риски major, где лежат бэкапы, откат

### Критерии готовности

- [x] Повторный `install_mariadb` больше не единственный путь; `db update` обновляет пакеты
- [x] Перед обновлением SQL-БД создаётся бэкап (если не `--no-backup`)
- [x] После update есть проверка (`SELECT 1` / `PING`)

### Результат

```
- cmd_db: status/update, --dry-run/--no-backup/--major
- Бэкапы в ~/.config-backups/db/; smoke после upgrade
- install_* указывает на db update; меню 30–31; dev db-update
```

### Заметки

```
dev db по-прежнему стартует сервисы БД; обновление — dev db-update.
```

---

## Этап 6 — модули и профили

**Статус:** готово  
**Зависимости:** этапы 2–5 желательны

### Целевая структура

```
bin/setup-dev-env
lib/common.sh
lib/install/{apache→web,nginx→web,php,database,tools,apps,scripts,system}.sh
lib/lang.sh
lib/db.sh
config/versions.env
profiles/{minimal,web,full,desktop}.conf
scripts/
templates/
```

### Шаги

- [x] 6.1 Вынести common (log, colors, prechecks) в `lib/common.sh`
- [x] 6.2 Разнести install-функции по `lib/install/*.sh`
- [x] 6.3 Тонкий `bin/setup-dev-env` как CLI
- [x] 6.4 Профили: `minimal` / `web` / `full` / `desktop`
- [x] 6.5 Сохранить обратную совместимость команд (`./setup-dev-env.sh all`, `php8.2`, …)
- [x] 6.6 Обновить README под новую структуру

### Результат

```
- Монолит разбит: lib/load.sh + modules; setup-dev-env.sh тонкий wrapper
- profiles/*.conf + `profile` CLI; меню п.32
- Бэкап монолита: setup-dev-env.monolith.bak.sh (gitignore)
- lang/db оставлены как lib/lang.sh и lib/db.sh (не дробление по 1 файлу на движок)
```

### Заметки

```
Дальнейшее дробление lib/lang/{php,go,node}.sh — по желанию; функционально уже модульно.
```

---

## Этап 7 — CI, health, Mailpit

**Статус:** готово  
**Зависимости:** этап 6 (частично можно раньше: ShellCheck на текущем файле)

### Шаги

- [x] 7.1 ShellCheck в CI (GitHub Actions) + локальный скрипт проверки
- [x] 7.2 Smoke: `bash -n`, `--help`, `lang list`, `db status`, `db update --dry-run`
- [x] 7.3 Расширить `health`: все PHP-FPM, Apache 8080/8443, Xdebug, mkcert, outdated БД/языков
- [x] 7.4 Замена MailHog → Mailpit (или опция выбора) + обновление PHP mail path и README
- [x] 7.5 Docker Compose шаблон для legacy PHP 7.x
- [ ] 7.6 (Опционально) `update` / `uninstall` / `--dry-run` для компонентов → бэклог
- [x] 7.7 CHANGELOG + теги релизов (CHANGELOG.md; тег — вручную при релизе)

### Результат

```
- .github/workflows/ci.yml + scripts/check.sh
- health расширен; Mailpit default; docker/legacy-php/
- CHANGELOG.md; 7.6 отложен в бэклог
```

### Заметки

```
Тег git: git tag -a v1.0.0 -m "phpdev modular + mailpit" && git push --tags
```

---

## Бэклог

Идеи вне текущего scope. Переносите в этапы приоритизацией.

- [ ] Поддержка Ubuntu 22.04 / Debian
- [ ] Python через pyenv / deadsnakes как ещё один `lang`
- [ ] `new-project --type=wordpress|yii`
- [ ] Готовые run/debug конфиги PhpStorm/Cursor в шаблоне проекта
- [ ] Vagrant / cloud-init: чистая VM → `web --no-input`
- [ ] Opt-in вместо обязательного Papirus / части desktop-пакетов
- [ ] Общий `uninstall` / component `--dry-run` (бывший 7.6)

---

## Журнал обновлений плана

| Дата | Что изменено |
|------|----------------|
| 2026-09-07 | Создан план: этапы 0–7, языки, БД, модули, CI |
| 2026-09-07 | Этап 0 выполнен: политика PHP, README, LICENSE, .gitignore, без ja-netfilter |
| 2026-09-07 | Этап 1 выполнен: pipefail, apt/wget helpers, run_full_install, устойчивый apps |
| 2026-09-07 | Этап 2 выполнен: scripts/ + templates/, install_from_repo |
| 2026-09-07 | Этап 3 выполнен: config/versions.env, state installed.env |
| 2026-09-07 | Этап 4 выполнен: lang list/add/update/default/remove |
| 2026-09-07 | Этап 5 выполнен: db status/update, бэкапы, --major |
| 2026-09-07 | Этап 6 выполнен: lib/*, profiles/*, bin/setup-dev-env |
| 2026-09-07 | Этап 7 выполнен: CI, health, Mailpit, legacy Docker; план 0–7 закрыт |

<!--
Шаблон записи при пошаговом обновлении:

### YYYY-MM-DD — этап N, шаг N.M
- Статус этапа: …
- Сделано: …
- Следующий шаг: …
-->
