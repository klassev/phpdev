# Legacy PHP 7.4 (Docker)

PHP 7.4 на хосте ставится через `./setup-dev-env.sh php7.4` (packages.sury.org).
Этот Compose — изолированный вариант (или для PHP 7.3 / старых окружений без apt).

```bash
cd docker/legacy-php
docker compose up -d
# http://localhost:8074

# свой проект:
WWW_HOST_PATH=$HOME/www/old-site.test docker compose up -d
```

FPM-профиль (порт 9074):

```bash
docker compose --profile fpm up -d
```
