# Legacy PHP 7.4 (Docker)

На Ubuntu 24.04 пакеты PHP 7.x через apt обычно недоступны. Этот Compose поднимает PHP 7.4 в контейнере.

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
