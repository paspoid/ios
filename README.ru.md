# Paspo ID iOS SDK

[English](README.md) | Русский

SDK добавляет в ваше iOS-приложение вход через **Paspo ID**. Пользователь авторизуется существующим аккаунтом Paspo в пару касаний, а ваш сервер получает подтверждённые данные профиля — телефон, e-mail или номер документа — без того, чтобы вы сами их собирали, проверяли и хранили.

## Содержание

- [Обзор](#обзор)
- [Требования](#требования)
- [Установка](#установка)
- [Настройка проекта](#настройка-проекта)
- [Быстрый старт: готовая кнопка](#быстрый-старт-готовая-кнопка)
- [Своя интеграция](#своя-интеграция)
- [Вход, начатый из Paspo](#вход-начатый-из-paspo)
- [Проверка доступности](#проверка-доступности)
- [Схема авторизации](#схема-авторизации)
- [Справочник](#справочник)
- [Безопасность](#безопасность)
- [Поддержка](#поддержка)

## Обзор

Интеграция — это один вызов `authenticate(scope:nonce:)`, который возвращает одноразовый код авторизации. Приложение передаёт код на свой сервер, а тот обменивает его в Paspo на данные пользователя. Со стороны пользователя всё выглядит так: нажать «Войти через Paspo ID», подтвердить на экране согласия и вернуться в приложение.

Обмен между приложением и Paspo сквозно зашифрован (ECDH P-256 + AES-256-GCM, эфемерные ключи живут только в памяти) и полностью берётся на себя SDK — криптографии на вашей стороне не требуется.

Две обязанности остаются на вашем сервере и не могут быть перенесены на клиент, потому что именно на них держится безопасность схемы: генерация `nonce` и обмен кода авторизации на данные пользователя.

## Требования

| | |
|---|---|
| Deployment target | iOS 15.0 |
| Swift | 5.9 |
| Конкурентность | обязательна; `authenticate` — `async`-метод |

Самому приложению Paspo ID нужна более новая iOS, чем SDK. Там, где его нельзя установить, `authenticate` вернёт `.notInstalled` — это штатный исход, его нужно обработать. Кнопку можно скрыть заранее через `isPaspoInstalled`.

## Установка

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/pingocean/paspo-ios-sdk", from: "1.0.0"),
]
```

```swift
.product(name: "PaspoID", package: "paspo-ios-sdk"),      // ядро, headless API
.product(name: "PaspoIDUI", package: "paspo-ios-sdk"),    // опционально, готовая кнопка
```

В Xcode: **File → Add Package Dependencies…** и вставьте URL репозитория.

### CocoaPods

```ruby
pod 'PaspoID', '~> 1.0'
pod 'PaspoIDUI', '~> 1.0'
```

### XCFramework

Собранные бинарники приложены к каждому релизу на GitHub. Перетащите `PaspoID.xcframework` в **Frameworks, Libraries, and Embedded Content** и выберите *Embed & Sign*. Собрать самому: `./scripts/build-xcframework.sh`.

## Настройка проекта

**1. Redirect URL.** Paspo ID возвращает результат, открывая URL, принадлежащий вашему приложению. Используйте Universal Link на своём домене:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:your.app</string>
</array>
```

Путь должен быть указан в файле `apple-app-site-association` вашего домена. В симуляторе Universal Links не резолвятся, пока AASA недоступен, поэтому в разработке обычно добавляют запасную custom-схему через `CFBundleURLTypes`.

Оба URL нужно зарегистрировать в Paspo при онбординге — приложение отклоняет неизвестные ему redirect-адреса.

**2. Схема `paspo` в `LSApplicationQueriesSchemes`**, чтобы SDK мог проверить, установлено ли приложение Paspo ID.

**3. Маршрутизация входящих URL в SDK:**

```swift
@main
struct YourApp: App {
    init() {
        Paspo.configure(
            PaspoConfiguration(
                redirectURL: URL(string: "https://your.app/paspo/callback")!,
                fallbackRedirectURL: URL(string: "yourapp://paspo-callback")!
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { Paspo.shared.handle(url: $0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    Paspo.shared.handle(url: url)
                }
        }
    }
}
```

В UIKit вызывайте `Paspo.shared.handle(url:)` из `scene(_:openURLContexts:)`, `scene(_:continue:)` и `scene(_:willConnectTo:options:)`.

## Быстрый старт: готовая кнопка

![Кнопка входа Paspo ID](buttons.svg)

Кнопка сама проводит весь сценарий по нажатию и блокирует повторные нажатия, пока идёт запрос. Ей нужны две вещи: провайдер nonce и обработчик результата.

```swift
PaspoSignInButton(
    nonceProvider: backend.requestSsoNonce,
    onResult: onPaspoResult
)
```

```swift
private func onPaspoResult(_ result: PaspoAuthResult) {
    switch result {
    case let .success(authCode): Task { try await backend.signIn(authCode: authCode) }
    case let .failure(error, _): show(message(for: error))
    case .cancelled, .notInstalled: break
    }
}
```

Внешний вид настраивается под ваше приложение:

```swift
PaspoSignInButton(
    scope: .phones,
    theme: .light,        // .brand (по умолчанию), .light, .dark, .neutral
    cornerRadius: 12,     // по умолчанию — «пилюля»
    nonceProvider: backend.requestSsoNonce,
    onResult: onPaspoResult
)
```

Для UIKit есть `PaspoSignInButtonView` с методом `setAuthHandler(scope:nonceProvider:onResult:)`. Если `nonceProvider` бросает ошибку, результат будет `.failure(error: .serviceUnavailable, ...)`.

## Своя интеграция

```swift
let nonce = try await backend.requestSsoNonce()
let result = await Paspo.shared.authenticate(scope: .phones, nonce: nonce)
```

Метод не бросает исключений: отмена, отсутствие приложения Paspo ID и любые ошибки возвращаются как `PaspoAuthResult`.

Два ограничения:

- одновременно выполняется только один `authenticate`; новый вызов отменяет предыдущий;
- экземпляр SDK должен пережить переход в Paspo ID и обратно — результат приходит URL-ом. Используйте `Paspo.shared` либо держите свой экземпляр там, где он не пересоздаётся при уходе приложения в фон.

## Вход, начатый из Paspo

Пользователь может начать вход из самого Paspo. Тогда Paspo откроет ваш redirect URL с меткой `paspo_signin` без остальных данных. Поддержка этой точки входа необязательна:

```swift
if Paspo.shared.isSignInRequest(url: url) { startSignIn() }
```

## Проверка доступности

```swift
if Paspo.shared.isPaspoInstalled { /* приложение установлено */ }
```

Проверка необязательна: `authenticate` делает её сам и при отсутствии Paspo ID открывает страницу App Store из `PaspoConfiguration.appStoreURL`, возвращая `.notInstalled`.

`cleanup()` сбрасывает текущий сценарий и уничтожает эфемерный ключ. SDK вызывает его сам при завершении и ошибках; вручную — только если вы прерываете вход сами, например когда пользователь уходит с экрана.

## Схема авторизации

```mermaid
sequenceDiagram
    participant B as Ваш сервер
    participant A as Ваше приложение (SDK)
    participant P as Приложение Paspo ID
    participant PS as Сервер Paspo

    A->>B: запрос nonce
    B-->>A: nonce
    A->>P: paspo://sso?pub&nonce&scope&redirect&state
    Note over A,P: эфемерный ключ ECDH, сквозное шифрование
    P->>PS: проверка клиента, шаги подтверждения
    Note over P: экран согласия
    P-->>A: redirect URL с зашифрованным конвертом
    Note over A: расшифровка → .success(authCode)
    A->>B: authCode
    B->>PS: обмен authCode (server-to-server)
    PS-->>B: данные профиля
```

## Справочник

### PaspoScope

| Значение | Что получит ваш сервер |
|---|---|
| `.phones` | Номера телефонов |
| `.emails` | Адреса электронной почты |
| `.nationalID` | Номер документа, удостоверяющего личность |
| `.paspoID` | Постоянный идентификатор пользователя в Paspo |

### PaspoAuthResult

| Случай | Данные | Действие |
|---|---|---|
| `.success` | `authCode: String` | Отправить `authCode` на свой сервер |
| `.cancelled` | — | Пользователь закрыл экран согласия; обычно UI ошибки не нужен |
| `.notInstalled` | — | Paspo ID не установлен; SDK уже открыл App Store |
| `.failure` | `error`, `message` | Показать ошибку. `message` — для логов, не для пользователя |

### Ошибки

| Код | Случай | Значение |
|---|---|---|
| 100 | `.unknown` | Неизвестная ошибка |
| 101 | `.invalidRequest` | Некорректный запрос или повреждённые данные |
| 102 | `.serviceUnavailable` | Paspo временно недоступен |
| 103 | `.cancelled` | Пользователь отменил операцию |
| 110 | `.sessionExpired` | Сессия истекла; начните заново с новым nonce |
| 111 | `.packageVerificationFailed` | Приложение не прошло проверку Paspo. Проверьте, что bundle id и redirect URL зарегистрированы при онбординге |
| 120 | `.accessDenied` | Пользователь отказал в доступе |
| 121 | `.identityNotVerified` | Личность пользователя не подтверждена в Paspo |
| 122 | `.attemptsExceeded` | Слишком много попыток |
| 123 | `.actionNotAllowed` | Недоступно для этого пользователя |
| 130 | `.authMethodUnavailable` | Метод подтверждения временно недоступен |
| 131 | `.unsupportedAuthMethod` | Метод подтверждения не поддерживается |
| 140 | `.paspoNotInstalled` | Paspo ID не установлен |
| 141 | `.cryptoError` | Ошибка шифрования или расшифровки; повторите сценарий |

Коды совпадают с Android SDK — таблица ошибок одна на обе платформы.

## Безопасность

- Ключи эфемерные: на каждый `authenticate` генерируется новая пара ECDH, живёт только в памяти процесса и уничтожается после расшифровки ответа.
- Каждый ответ несёт `state` своего запроса; колбэки, не совпадающие с текущим сценарием, игнорируются — чужое приложение не подсунет результат.
- Генерируйте `nonce` на сервере и там же проверяйте его при обмене кода — это защита от повторного воспроизведения.
- `authCode` одноразовый и сам по себе не содержит персональных данных; данные пользователя передаются только по вашему защищённому каналу server-to-server.
- Для `redirectURL` предпочитайте Universal Link: custom-схему может занять другое приложение.
- Не логируйте `nonce` и код авторизации.
- `PaspoIDWire` — общий контракт обмена, а не публичное API; он открыт для самого приложения Paspo ID и может измениться в любом релизе.

## Поддержка

По вопросам онбординга (регистрация bundle id и redirect URL приложения, серверный API обмена): [paspo.id](https://paspo.id).
