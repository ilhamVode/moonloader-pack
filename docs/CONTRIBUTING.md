# Contributing

## Ветки

- `main` — стабильная ветка. Всё что в `main` — уже у игроков.
- `dev/*` — ветки разработчиков. Одна задача = одна ветка.

## Процесс

Разработчик хочет обновить свой скрипт:

```bash
git checkout main
git pull
git checkout -b dev/lavaka
# меняешь файл, обновляешь версию и changelog
git add .
git commit -m "Update Lavaka to 1.1.0"
git push -u origin dev/lavaka-fix
```

Создаёшь Pull Request: `dev/lavaka-fix → main`

Я проверяю и merge. После merge игроки сразу видят обновление в менеджере.

## Commit message

Пиши коротко и по делу:
- `Fix manager button overlap`
- `Update Lavaka to 1.1.0`
- `Add InfoZZ database download`

## Changelog

В manifest.json пиши то, что увидит пользователь. Не технические детали.
