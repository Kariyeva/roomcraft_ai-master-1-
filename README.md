# RoomCraft AI

Flutter-приложение для интерьерных концепций с Firebase Auth / Firestore и Node.js / Replicate backend.

Реализованы главная страница, дизайн-система, кабинет дизайнера, список проектов и мастер создания. Проекты используют прежний `savedWorks`, сохраняя чтение старых работ. [Аудит](docs/AUDIT.md) · [Отчёт второго этапа и список файлов](docs/STAGE_2.md).

## Запуск Flutter

Использован Flutter 3.47.5 / Dart 3.13.4. Минимальный Dart по pubspec: 3.11.

```sh
flutter pub get
flutter run -d chrome --web-port 7357 --dart-define=API_BASE_URL=http://localhost:3000
```

Публичная страница открывается на `/`. После входа — кабинет `/mode`; коллекция — `/projects`, мастер — `/project/new`, профиль — `/profile`. Firebase использует имеющийся `lib/firebase_options.dart`. Проект создаётся после четырёх шагов; AI запускается отдельно со страницы сохранённого проекта.

```sh
flutter analyze
flutter test
flutter build web --release
```

Результат сборки: `build/web`. Публикация не выполнялась.

## Backend: этап 3, часть 1

[Отчёт о безопасности и обязательные ручные действия](docs/SECURITY_STAGE_3.md). Новая AI Studio ещё не реализуется. AI по умолчанию выключен до проверки server-only журнала, правил и аккаунтов.

Нужен Node.js 22+ и актуальное обновление Node. Подготовьте `backend/.env` из `.env.example`, credentials Firebase вне git и Replicate token в серверном окружении. Не передавайте секреты в чат или Flutter dart-define.

```sh
cd backend
npm ci
npm test
npm start
```

Начальная конфигурация `AI_ENABLED=false`, `AI_LEDGER_RULES_CONFIRMED=false`. В Render вручную задаются environment, Secret File и точные ALLOWED_ORIGINS; `render.yaml` не развёрнут. Перед включением обязательно прочитайте раздел проверки Rules в отчёте.

Flutter и редактор используют единый публичный `API_BASE_URL`. Без dart-define платные запросы запрещены. Генерация комнаты требует сохранённого проекта. Ответ — защищённая операция с polling и base64-изображением; старый публичный `/generated` больше не раздаётся. Старые URL требуют инвентаризации до rollout.

```sh
flutter build web --release --dart-define=API_BASE_URL=https://YOUR-STAGING-API.example
```

URL API не секрет. Firebase ID token получается во время работы из Firebase Auth. Токен Replicate находится только на backend.

## Проверки и ограничения

Второй этап: `flutter analyze` — без замечаний; `flutter test` — 33 успешных теста, включая адаптивность 320/375/768/1024/1440 px; release Web собирается. Полный отчёт и границы проверок — [STAGE_2.md](docs/STAGE_2.md).

Firebase-записи, правила двух пользователей и реальная платная AI-генерация требуют ручной проверки с тестовыми аккаунтами. Тесты используют хранилище в памяти и не доказывают работоспособность production. Публикация не выполнялась.

Проекты и прежние работы живут в одной коллекции `users/{uid}/savedWorks`. Миграция прежних документов не требуется. Фото оптимизируется до 1600 px / 220 КБ; полноценный файловый Storage и история версий — следующий этап. Для создания нужен интернет. Подробнее о дополнительных полях и совместимости правил — в отчёте.

Этап 3, часть 1: backend 22 passed / 1 emulator test skipped; Flutter 41 passed; npm audit — 0 известных уязвимостей. Платная генерация, live Firebase и Render не проверены. Детали и точные границы проверок — в [отчёте](docs/SECURITY_STAGE_3.md).
