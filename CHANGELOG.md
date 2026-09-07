# Changelog

## Unreleased

### Added
- Модульная структура `lib/`, `bin/setup-dev-env`, профили `minimal|web|full|desktop`
- `lang` / `db` CLI, `config/versions.env`, state `~/.config/phpdev/installed.env`
- Mailpit по умолчанию (`MAIL_CATCHER`), legacy MailHog опционально
- Docker Compose для PHP 7.4: `docker/legacy-php/`
- CI (GitHub Actions) и `./scripts/check.sh` (bash -n, smoke, shellcheck)
- Расширенный `health` (все PHP-FPM, Apache 8080/8443, Xdebug, mkcert, outdated Go)

### Changed
- PHP apt по умолчанию только 8.1–8.4; PHP 7.x — Docker / best-effort
- Утилиты `dev` / `new-project` / `vhost` вынесены в `scripts/`

### Security
- Убрана рекомендация ja-netfilter для PhpStorm
