# Этап 3, часть 1 — backend и безопасность

Дата: 20 октября 2026. Интерфейс новой AI Studio, три варианта и пользовательская история генераций в эту часть не входят. Production не развёртывался и не изменялся.

## Доступная конфигурация и границы проверки

Прочитаны AUDIT.md, STAGE_2.md, README, Flutter-маршруты/сервисы/запросы, Node backend и Firebase-конфигурация. Доступна публичная Firebase-конфигурация `roomcraft-ai-c4bf7`. На момент проверки отсутствовали backend/.env, сервисный аккаунт, REPLICATE_API_TOKEN, GOOGLE_APPLICATION_CREDENTIALS, FIREBASE_PROJECT_ID и переменные Render в окружении. Значения секретов не выводились. Доступа к Firebase Console и панели/секретам Render нет.

Реальные Firebase-записи, действующие токены, production rules, Replicate inference и биллинг не проверены. Никаких платных prediction не создавалось. Наличие официальных страниц моделей и соответствие транспортного контракта не доказывают успешную генерацию.

## Реализованная защита

### Авторизация и проекты

- `/generate-room` и `/remove-background` требуют `Authorization: Bearer <Firebase ID token>`. Используется настоящий Admin SDK `verifyIdToken(token, true)` с проверкой отзыва, issuer/audience/signature самим SDK. Нет development bypass или доверия client-side флагам. Анонимные Firebase-пользователи запрещены.
- UID берётся исключительно из проверенного токена. Legacy userId в body не используется как идентичность; несовпадение отклоняется. Flutter больше его не отправляет.
- Генерация комнаты требует projectId. Проект читается только из `users/{verifiedUid}/savedWorks/{projectId}`. Проверяются существование и, если указан, совпадение сохранённого userId. Чужой/отсутствующий проект даёт одинаковый 404. Путь не принимается от клиента, ID с `/` запрещены.
- Удаление фона может работать без проекта для собственного предмета зарегистрированного пользователя. Если projectId указан, он также проверяется.
- Перед чтением результата проверяются токен, UID операции и доступность проекта. Удалённый проект не даёт доступа к результату через API.
- Авторизация Flutter прямых Firestore-запросов по-прежнему зависит от опубликованных rules: backend не способен исправить их клиентским кодом.

### Журнал, квоты и повторные списания

Новые служебные коллекции (Admin SDK, без миграции savedWorks):

```
_aiSecurityUsers/{uid}                         # minute/day/concurrency counters
_aiSecurityUsers/{uid}/operations/{key}        # operation or alias tombstone
_aiSecurityUsers/{uid}/fingerprints/{sha256}   # short duplicate window
_aiSecurityGlobal/limits                      # global daily/concurrency cap
```

Эти пути должны быть полностью закрыты для ВСЕХ клиентских Firestore SDK/REST-запросов. Они не размещены в редактируемом пользователем users/{uid} документе.

- По умолчанию: 10 принятых AI-операций на пользователя в сутки UTC, 3 в минуту, 1 незавершённая на пользователя; глобально 100 в сутки, 3 незавершённых. Оба платных endpoint делят общий бюджет.
- Транзакция одновременно проверяет проект, idempotency key, SHA-256 запроса, пользовательские и общие лимиты и резервирует операцию. Это работает между процессами при настоящих Firestore transactions, а не только в памяти Node.
- `Idempotency-Key`: 16–128 букв/цифр/`_`/`-`. Другой payload с уже использованным ключом → 409. Такой же payload с другим ключом в течение 60 секунд возвращает исходную операцию и записывает alias нового ключа; дополнительной квоты/вызова провайдера нет.
- `reserved → submitting` выполняется compare-and-set транзакцией. Только победитель выполняет один платный POST Replicate. Повторные POST не имеют автоматических HTTP/SDK retries.
- Состояния: reserved, submitting, processing, succeeded, failed, canceled, requires_review. Пользовательский статус не имитирует проценты выполнения.
- После получения prediction ID его сохраняют до polling. После перезапуска GET статуса может продолжить чтение существующего prediction; он никогда не создаёт новый.
- При неоднозначном сетевом исходе POST без prediction ID слот остаётся заблокированным для проверки администратором. Угадывать, был ли запрос платным, и автоматически создавать второй prediction запрещено.
- Отказ/ошибка не возвращают дневную квоту автоматически. Это консервативный счётчик принятых операций, а не финансовый баланс или подтверждение фактического списания. Повторный ответ готовой операции квоту не расходует.
- Счётчики concurrency освобождаются транзакционно и только один раз при терминальном исходе. Операция с неизвестным исходом не освобождается по простой истёкшей lease.
- ID и алиасы нельзя автоматически удалять по TTL: это откроет возможность повторного платного POST с тем же ключом. Политика хранения результатов и компактных tombstones требует отдельного решения.

Ограничение: транзакция Firestore и платный POST стороннего API не являются общей распределённой транзакцией. Абсолютная гарантия exactly-once биллинга не заявляется. Реализованы один create-вызов на canonical operation и запрет автоматической повторной отправки после неизвестного исхода. Квоты ограничивают число запросов, а не точную сумму в валюте.

### Сеть, файлы, результаты и логи

- CORS — точные origins из ALLOWED_ORIGINS, без `*`, null-origin и credentials. Production разрешает только HTTPS origins. Native-запросы без Origin допускаются, но всё равно требуют проверенный токен. CORS не заменяет авторизацию.
- Не доверяем X-Forwarded-For/Host/Proto для UID, денег или URL. Квоты привязаны к UID, не к spoofable IP.
- Перед загрузкой: проверка токена, флага rollout и ограничение числа запросов; multipart-only, один файл, до 10 МиБ, ограничены поля/части/boundary. Дополнительно ограничены одновременные загрузки и декодирования изображений в процессе.
- Sharp проверяет содержимое JPG/PNG, MIME и разрешение до 24 Мп; анимация/неподдерживаемые форматы отклоняются. Ввод нормализуется, metadata не пересылается. Проектное исходное фото не перезаписывается.
- Исходящие API-запросы имеют timeout (по умолчанию 20 секунд), prediction — Cancel-After 180s и локальный deadline. При известном ID по таймауту предпринимается best-effort cancel; успешная отмена/возврат средств не обещаются.
- Скачивание результата разрешено только с HTTPS replicate.delivery и его поддоменов, без URL credentials/произвольных портов, redirects отключены, скачиваемые байты ограничены. Изображение повторно декодируется перед выдачей.
- Новые результаты не записываются в публичный generated/. Они нормализуются до максимум 1400 px / 400 000 байт (дополнительное уменьшение при необходимости), хранятся в закрытом журнале и выдаются base64 только владельцу через API. Для удаления фона сохраняется PNG/прозрачность; для комнаты — JPEG.
- Не добавлены токены в URL, публичные signed links, output URLs провайдера или секретные ключи во Flutter. Ответы no-store, nosniff, no-referrer.
- Общий timeout HTTP-обработчика 30 секунд, отдельный timeout проверки авторизации 15 секунд. POST возвращает 202 с operationId; длительная работа не удерживает соединение Render.
- Логи содержат только тип события, безопасный код, случайный requestId и валидированный operationId. Нет req.body, Authorization, UID/email, фотографий, пожеланий, SDK stack или provider diagnostics. Ошибки пользователю фиксированные и понятные.

### Flutter: только совместимый защищённый транспорт

`AiBackendClient` получает Firebase ID token из текущего User, отправляет projectId и idempotency key, опрашивает защищённый статус. Единый `API_BASE_URL` задаётся через dart-define; прежние разрозненные Render/Railway/localhost адреса удалены из инструментов. Без явного URL запросы запрещены. HTTPS обязателен, кроме явных loopback/emulator адресов для локальной разработки.

Незавершённые ID и hash сохраняются в SharedPreferences под UID/типом операции; токен, фото и prompt там не хранятся. После потери ответа или перезагрузки сначала выполняется GET существующей операции, а при 404 — один POST с тем же ID. Новый набор параметров не заменяет незавершённый запрос молча. Дубли с canonical ID корректно продолжают polling по исходному ID. Смена аккаунта или закрытие экрана останавливает клиентское ожидание, сохраняя ID для восстановления. Перенаправления для запросов с bearer-токеном запрещены; объём ответа ограничен при чтении stream. Внутрипроцессный guard не даёт конкурентным вызовам затереть ключ; безопасность денег по-прежнему обеспечивается сервером.

Результат передаётся в прежний экран результата как bytes и сохраняется прежним сервисом в тот же проект. Редактор использует тот же авторизованный транспорт для удаления фона. Новые интерфейсы сравнения/истории/трёх вариантов не реализованы.

## Модели и зависимости

Сохранены `black-forest-labs/flux-kontext-pro` и версия `851-labs/background-remover:a029dff38972b5fda4ec5d75d7d1cd25aeff621d2cf4946a41055d7db66b80bc`. Вместо непрозрачного `replicate.run()` используется официальный HTTP API с явными create/get/cancel без retries платного POST. Убраны дополнительные prompt_strength/guidance_scale; остался минимальный image-editing input.

Прежний buildStrictPrompt оставлен без изменения задачи: он требует небольших правок, а не полного redesign. Требования prompt не являются гарантией сохранения планировки. Пересмотр сценария и prompt — часть 2 после подтверждения.

Firebase Admin обновлён до 14.5 с модульными imports; Node.js 22+. Добавлен Sharp. `npm audit fix` устранил совместимые проблемы, переход Admin 14 устранил оставшуюся уязвимую цепочку. Контрольный npm audit: **0 известных уязвимостей**, не гарантия отсутствия всех ошибок.

Официальные источники, проверенные при реализации:

- [Firebase ID tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens), [session revocation](https://firebase.google.com/docs/auth/admin/manage-sessions).
- [Firebase Admin release notes](https://firebase.google.com/support/release-notes/admin/node).
- [Replicate async/polling/deadlines](https://replicate.com/docs/topics/predictions/create-a-prediction), [HTTP API](https://replicate.com/docs/reference/http/).
- [FLUX Kontext Pro](https://replicate.com/black-forest-labs/flux-kontext-pro/api), [background-remover version](https://replicate.com/851-labs/background-remover/versions/a029dff38972b5fda4ec5d75d7d1cd25aeff621d2cf4946a41055d7db66b80bc).
- [Render environment variables](https://render.com/docs/environment-variables).

## Безопасное включение: действия владельца

Ничего из нижеперечисленного автоматически не применено. Не отправляйте ключи в чат и не добавляйте их в git.

1. Создайте staging Firebase/Render-конфигурацию или отдельно согласуйте использование существующего проекта. Выдайте серверному сервисному аккаунту минимальные необходимые Auth read/revocation-check и Firestore permissions; не используйте пользовательский Owner-ключ. Сохраните JSON вне репозитория. Убедитесь, что project_id соответствует FIREBASE_PROJECT_ID.
2. Локально скопируйте backend/.env.example в backend/.env и самостоятельно укажите файл credentials и Replicate token. Альтернатива — GOOGLE_APPLICATION_CREDENTIALS для ADC. NODE_ENV=production не допускает emulator hosts. Auth emulator запрещён runtime-сервером во всех режимах, а платный AI не может использовать эмулированный ledger даже в development. Отдельный integration test напрямую использует demo Firestore emulator без платных вызовов.
3. В Render вручную создайте Secret File `firebase-service-account.json` и укажите путь `/etc/secrets/firebase-service-account.json`; Replicate token — только server environment. render.yaml — подготовленный blueprint, не выполненная публикация.
4. Проверьте и согласуйте Firestore Rules до включения. Требуется запрет любых клиентских чтений/записей служебных коллекций и изоляция users/{uid}/savedWorks по request.auth.uid. Пример служебных матчей внутри существующего `/databases/{database}/documents`:

```
match /_aiSecurityUsers/{document=**} { allow read, write: if false; }
match /_aiSecurityGlobal/{document=**} { allow read, write: if false; }
```

Это НЕ готовая production policy. Пересекающийся широкий `allow` разрешает доступ даже при таком deny-матче: правила необходимо проверить целиком. Не выкладывайте emulator deny-all fixture в production.

5. Проверьте authenticated и unauthenticated клиентским SDK/REST: ни пользователь A, ни B не могут читать/править квоты, operations или aliases. A не может читать/писать проекты B. Admin SDK должен работать с журналом. Новым коллекциям сейчас не нужен TTL или composite index; автоматически их не создаём.
6. Укажите точные frontend origins (scheme/host/port, без пути и завершающего slash) в ALLOWED_ORIGINS. Для локального Flutter используйте web-port 7357. Для опубликованного Web — его фактический HTTPS origin. Настройте HTTPS API URL через Flutter dart-define. URL не секрет; Replicate token в dart-define запрещён.
7. Сначала оставьте AI_ENABLED=false. Только после проверки policy выставьте AI_LEDGER_RULES_CONFIRMED=true и отдельно AI_ENABLED=true. Флаг подтверждения — запись о ручной проверке, не техническая замена правил. Если правила проверить нельзя, генерация должна оставаться отключённой.
8. До платного smoke test согласуйте один запрос, аккаунт, лимиты и наблюдение за расходами Replicate. Не меняйте платёжные настройки автоматически. Для пилота можно вручную уменьшить global concurrency до 1 и суточные лимиты. Учитывайте: лимиты — число допущенных запросов, failed/unknown тоже учитываются.
9. Проверьте реальный сценарий: валидный/истёкший/отозванный токен; чужой проект; один успешный запрос; повтор с тем же ID; повтор тех же байт с другим ID; разрыв связи и перезапуск; отсутствие нового prediction в Replicate при повторе. Убедитесь, что исходное фото и число проектов не изменились после сохранения результата.

### Операторское восстановление неизвестного исхода

Не удаляйте operation/tombstone и не сбрасывайте daily counters, чтобы «починить повтор». Это может открыть повторное списание.

Подготовлена `npm --prefix backend run review:operation -- --uid USER_UID --operation OPERATION_ID`. По умолчанию она только читает журнал и известный provider status и не создаёт prediction. Нужны ваши серверные credentials; утилита здесь не запускалась против реальных аккаунтов.

После отдельного согласования изменений production и отключения новых AI-запросов `--apply` может закрыть операцию: при известном ID — только после подтверждённого терминального provider status; при succeeded скачает готовый результат, при failed/canceled освободит concurrency. Ни create, ни новый платный запрос утилита не вызывает.

Если prediction ID неизвестен, автоматического доказательства исхода нет. Администратор должен проверить Replicate history/billing, дождаться grace period (deadline + HTTP timeout + 60s) и лишь затем, после согласования, использовать `--apply --confirm-no-active-prediction`. Это человеческое подтверждение, не обещание отсутствия прошлого списания. Daily quota не возвращается.

## Проверки

- Backend: **22 passed, 1 skipped**. Реальные HTTP-запросы к локальному Express, настоящие multipart/Sharp, unit-транзакции на test double, тесты provider HTTP-контракта, загрузка реального Firebase Admin и отказ malformed token, отказ старта без credentials/CLI без identity. Подмены Auth/Replicate применены только в тестах; реального inference нет.
- Пропущен отдельный actual Firestore emulator integration test: эмулятор не запущен. Настоящие распределённые транзакции и live client-deny rules этим прогоном не подтверждены.
- Flutter: **41 passed**, включая прежние адаптивные сценарии и 8 транспортных тестов (токен/ID, потеря ответа, canonical replay, смена аккаунта, конкуренция, 401, отсутствующий URL).
- `flutter analyze --no-pub`: No issues found.
- `flutter build web --release --no-pub --dart-define=API_BASE_URL=http://localhost:3000`: успешно, build/web. Есть прежнее не блокирующее сборку сообщение SDK о Cupertino font family. Сборка для реального staging требует его HTTPS URL; публикация не выполнялась.
- `npm audit`: 0 известных уязвимостей после обновлений.
- Не проверены: действующие Firebase tokens/rules/IAM, Render startup и proxy в реальном аккаунте, фактический provider inference/стоимость, реальное сохранение результата после генерации.

Дополнительная локальная интеграция (потребуются Firebase CLI и Java для Firestore emulator, устанавливаются отдельно):

```sh
npx firebase-tools emulators:exec --only firestore --config backend/firebase.emulator.json --project demo-roomcraft 'npm --prefix backend test'
```

Это отдельный demo-emulator, не ваша production-конфигурация. Тест запрещает удалённый emulator host и использует demo project ID.

## Оставшиеся ограничения и следующий шаг

- Проектные Firestore rules, оригиналы в savedWorks и локальные custom items сохраняют ограничения этапа 2. Backend не делает доступными безопасными старые прямые клиентские пути без проверки rules.
- Публичный `/generated` удалён из нового backend. Старые файлы не удаляются кодом, но старые ссылки после обновления сервера не обслуживаются. До rollout инвентаризируйте такие работы, сохраните доступные превью/оригиналы и согласуйте перенос в приватное хранилище. Не включайте старую публичную раздачу ради совместимости.
- Оригиналы/результаты высокого разрешения и долговечная политика хранения требуют приватного Storage и отдельного согласования. Base64 в закрытом Firestore — ограниченный по размеру промежуточный способ; он имеет storage/read costs.
- Не реализованы queue с отдельным worker, webhooks, user-facing history, три варианта, сравнение, точечные маски или автоматический retry оплаченного POST.
- Часть 2 не начинается без подтверждения пользователя.

## Файлы части 1

Backend: server.js, package.json, package-lock.json; новые src/app.js, config.js, errors.js, images.js, ledger.js, prompts.js, provider.js; scripts/review-operation.js; .env.example; firebase.emulator.json; test/security.test.js, fake-firestore.js, firestore.integration.test.js, firestore.rules.

Frontend: новый lib/services/ai_backend_client.dart и test/ai_backend_client_test.dart; минимальные изменения lib/screens/04_ai_create.dart, 06_editor.dart, pubspec.yaml/pubspec.lock.

Конфигурация/отчёты: .gitignore, render.yaml, README.md, docs/SECURITY_STAGE_3.md, docs/AUDIT.md. Изменения этапов 1–2 сохранены.
