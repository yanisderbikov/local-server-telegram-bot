# Telegram Local Bot API Server

Контейнер официального [tdlib/telegram-bot-api](https://github.com/tdlib/telegram-bot-api), режим `--local`. Исходники и TDLib фиксируются Git commit, а не плавающим `latest`. По умолчанию commit `e3e9dd8e5b3d7ab8537cd5a10dc31d5ffa8f82d1`.

## Запуск вместе с Java-ботом

Рекомендуемый вариант: клонировать этот репозиторий рядом с `video-audio-bot` и запустить **только** Compose из Java-репозитория. Он собирает этот Dockerfile, создаёт общую сеть и общий volume. Не запускайте одновременно второй Local API для того же токена.

## Отдельный запуск

```sh
cp .env.example .env
# Заполнить TELEGRAM_API_ID и TELEGRAM_API_HASH.
docker compose up -d --build
```

`api_id` и `api_hash` — данные Telegram приложения. Они отличаются от токена бота. Все настройки находятся в `.env.example`; параметры сборки передаются Docker build args. Первая сборка TDLib может занять заметное время и несколько ГБ RAM. `BUILD_JOBS=1` уменьшает параллелизм сборки.

Контейнер работает как UID/GID `10001:10001`. Для bind mount владелец каталогов должен соответствовать этому UID/GID. Java-приложение должно видеть тот же каталог данных. Его `TELEGRAM_SERVER_DIRECTORY` — путь внутри этого контейнера, `TELEGRAM_LOCAL_DIRECTORY` — соответствующий путь внутри Java-контейнера. Общий Compose уже согласует их.

Перед переносом существующего бота с облачного API один раз вызовите `logOut` в облачном API. В Java-репозитории есть `scripts/telegram-setup.sh logout-cloud`. После переноса все методы вызываются через Local API. По умолчанию приложение использует long polling; старый webhook нужно удалить с `drop_pending_updates=false`.

API доступен только на loopback хоста в отдельном Compose. Он не предназначен для открытого доступа из интернета. Общий Compose Java-проекта вообще не публикует его порт. S3 и Java-бот удаляют только скачанные файлы завершённых задач; служебные файлы TDLib остаются на постоянном volume. Не удаляйте целиком каталог данных работающего сервера.

## Без общего volume (Railway)

Если потребитель не может смонтировать тот же volume, задайте `FILE_SERVER_TOKEN`. Тогда в контейнере рядом с API запускается nginx на `FILE_SERVER_PORT` (8082): `GET`/`DELETE` файлов из каталога данных с заголовком `Authorization: Bearer <token>`. Служебные файлы TDLib (`td.binlog`, базы, `temp/`) не отдаются. Порт только для приватной сети. На Railway также задайте `TELEGRAM_HTTP_IP_ADDRESS=::` — приватная сеть использует IPv6.

## Ограничения и проверка

Режим `--local` снимает лимит скачивания облачного Bot API в 20 МБ. Это не отменяет ограничения самого Telegram на отправку файлов пользователями. `getFile` возвращает абсолютный локальный путь.

CI собирает контейнер и запускает бинарник с `--version`; для этого Telegram credentials не требуются. Реальную авторизацию и скачивание проверьте после заполнения env.

[Официальное описание локального API](https://core.telegram.org/bots/api#using-a-local-bot-api-server).
