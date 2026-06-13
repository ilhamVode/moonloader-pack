# ModioZodio MoonLoader Pack

Репозиторий для игрового менеджера `modio_manager.lua`.

## Структура

- `manifest.json` - список скриптов, версий, дат обновления и raw-ссылок.
- `scripts/` - файлы, которые менеджер может установить или обновить из игры.

## Как опубликовать

1. Создай репозиторий `ilhamVode/moonloader-pack` на GitHub.
2. Залей в него `manifest.json` и папку `scripts`.
3. Raw-манифест должен быть доступен по адресу:

```text
https://raw.githubusercontent.com/ilhamVode/moonloader-pack/main/manifest.json
```

Если имя репозитория будет другим, поменяй `MANIFEST_URL` в `modio_manager.lua` и ссылки `url` в `manifest.json`.

## Обновление версии

1. Замени файл в `scripts/`.
2. Подними `version` и `updated_at` в `manifest.json`.
3. После этого в игре нажми `Проверить обновления` в менеджере.
