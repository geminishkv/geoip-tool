## Категорий OWASP Top 10 2025

***

### **A01:2025 – Broken Access Control**

**Нарушение контроля доступа** — приложение не ограничивает действия пользователей за пределами их полномочий. Атакующий может обращаться к чужим данным, повышать привилегии или выполнять действия без авторизации. В 2025 году в эту категорию также включены SSRF-атаки.

```java
// Отсутствует проверка владельца, следовательно пользователь меняет `id=123` на `id=124` в URL и получает информацию без каких-либо проверок на сервере

@GetMapping("/order/{id}")
public Order getOrder(@PathVariable Long id) {
    return orderRepository.findById(id)
        .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
}
```

***

### **A02:2025 – Security Misconfiguration**

**Неправильная конфигурация** — небезопасные настройки по умолчанию, открытые Actuator-endpoints, отключённые security-заголовки, дефолтные УЗ, то есть ошибки конфигурации встречаются на всех уровнях стека.

```yaml
# Spring Boot Actuator доступен без аутентификации и отдаёт `/actuator/env` с паролями и токенами без аутентификации

management:
  endpoints:
    web:
      exposure:
        include: "*"
  endpoint:
    env:
      enabled: true   # раскрывает переменные окружения с паролями
```

***

### **A03:2025 – Software Supply Chain Failures**

**Сбои цепочки поставок ПО** — охватывает уязвимые зависимости, CI/CD-пайплайны без проверок и верификации артефактов, неподписанные артефакты, скомпрометированные репозитории, Maven/Gradle репозитории по HTTP, отсутствие проверки контрольных сумм, SNAPSHOT-версии в production.

```xml
<!-- Зависимость подтягивается по HTTP без проверки контрольной суммы — MITM-атака подменяет JAR на вредоносный -->

<repository>
    <id>central</id>
    <url>http://repo.example.com/maven2</url>
    <checksumPolicy>ignore</checksumPolicy>
</repository>
```

***

### **A04:2025 – Cryptographic Failures**

**Криптографические сбои** — слабые алгоритмы типа MD5, SHA-1, DES, RC4, включая хранение паролей в открытом виде или с примитивным хешированием, недостаточная длина ключей.

```java
// MD5 без соли, взламывается rainbow tables

String hash = DigestUtils.md5Hex(password);
userRepository.save(new User(username, hash));
```

***

### **A05:2025 – Injection**

**Инъекции** - ввод без санитизации в интерпретатор: SQL, OS-команды, LDAP, SpEL, шаблонизаторы, типа FreeMarker, Velocity, Thymeleaf, JNDI, которая риводит к утечке данных или RCE.

```java
// Конкатенация строк в SQL
String query = "SELECT * FROM users WHERE username = '" + username + "'"; // Ввод: ' OR '1'='1 — вернёт всех пользователей
Statement stmt = connection.createStatement();
ResultSet rs = stmt.executeQuery(query);
```

***

### **A06:2025 – Insecure Design**

**Небезопасный дизайн** — проблемы заложены на уровне архитектуры: отсутствие rate limiting, нет проверок бизнес-логики, не предусмотрены fail-safe механизмы, захардкоженные лимиты.

```java
// Отсутствуют rate limit на сброс пароля и атакующий перебирает OTP без ограничений

public ResponseEntity<?> resetPassword(@RequestBody ResetRequest req){
    return passwordService.reset(req.getEmail(), req.getOtp());
}
```

***

### **A07:2025 – Authentication Failures**

**Сбои аутентификации** — слабые пароли, отсутствие MFA, небезопасные сессии, предсказуемые токены сброса пароля, отсутствие защиты от брутфорса, небезопасное хранение учётных данных.

```java
// JWT принимается без проверки подписи

Claims claims = Jwts.parser()
    .parse(token)        // отсутствие проверки подписи
    .getBody();
String role = claims.get("role", String.class);
```

***

### **A08:2025 – Software or Data Integrity Failures**

**Сбои целостности** — десериализация Java-объектов без обьявления ограничений, загрузка кода без проверки подписи, отключённая верификация TLS-сертификатов, JNDI injection, обновления по HTTP без проверки хеша.

```java
// Десериализация без фильтра типов, возможен RCE через gadget-цепочки

ObjectInputStream ois = new ObjectInputStream(request.getInputStream());
Object obj = ois.readObject();
```

***

### **A09:2025 – Security Logging & Alerting Failures**

**Сбои логирования** — отсутствие записи событий инфобеза, типа failed logins, access denied, privilege escalation, логирование паролей и токенов в открытом виде, отсутствие алертов для SIEM.

```java
// Ошибка аутентификации не логируется

if (!authService.authenticate(username, password)) {
    return ResponseEntity.status(401).build();
}
```

***

### **A10:2025 – Mishandling of Exceptional Conditions**

**Неправильная обработка исключений** - пустые catch-блоки, stacktrace в HTTP-ответах, fail-open поведение, то есть возврат  true  при исключении, потеря исключений в async-коде, некорректные HTTP-статус коды ошибок.

```java
// fail-open при любой ошибке доступ разрешается

public boolean isAuthorized(String token) {
    try {
        return jwtService.verify(token);
    } catch (Exception e) {
        return true; // получение доступа
    }
}
```
