# Contributing

## Ветки

- `main` — стабильная ветка для пользователей. Прямые пуши запрещены.
- `dev` — тестовая сборка. Новые изменения попадают сюда через PR.
- `feature/*` — ветки новых функций.
- `script/*` — ветки обновления скриптов.
- `release/*` — подготовка релиза.
- `hotfix/*` — срочные исправления `main`.

## Процесс

1. Создай ветку от `dev`: `git checkout -b script/my-fix dev`
2. Внеси изменения, обнови версию и changelog
3. Создай Pull Request в `dev`
4. После проверки — merge в `dev`
5. Релиз: `release/*` → `main` → tag

## Commit message

Пиши коротко и по делу:

- `Fix manager button overlap`
- `Update Lavaka to 1.1.0`
- `Add InfoZZ database download`

## Changelog

В manifest.json пиши то, что увидит пользователь. Не технические детали.
