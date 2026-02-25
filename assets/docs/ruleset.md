
## Ruleset

### **A01:2025 – Broken Access Controll (IDOR)**

> - IDOR (Insecure Direct Object References)
> - Missing Authorization (@PreAuthorize, @Secured)
> - Spring Security Misconfiguration
> - JWT Security Issues
> - Session Management
> - CORS Misconfiguration
> - File Access Control
> - URL/Referer-based Access Control
> - Privilege Escalation
> - API Key & Token Issues
> - Mass Assignment
> - GraphQL/WebSocket Access Control
> - Actuator Exposure
> - OAuth2/ SSO Issues
> - Multi-tenancy
> - Default Credentials, Rate Limiting, Error Messages

### **A02:2025 – Security Misconfiguration**

> - Spring Boot Misconfiguration (Actuator, Debug, CSRF, CORS, H2 Console, DevTools)
> - Security Headers (CSP, X-Frame-Options, HSTS, Cache-Control, X-Content-Type-Options)
> - Session Management (Timeout, HttpOnly, Secure, SameSite, Session ID in URL)
> - XML Parser Vulnerabilities (XXE - DocumentBuilder, SAXParser, XMLReader, Transformer, JAXB)
> - Verbose Error Messages (Stack Traces, SQLException, File Paths, Debug Logging)
> - Default Credentials (JDBC, Embedded DB, JMX)
> - Cloud Configuration (AWS, S3, DynamoDB, GCP Storage, Azure Storage)
> - Database Configuration (Hibernate, JPA DDL, Connection Pool, MongoDB)
> - Logging Sensitive Data (Passwords, Credit Cards, JWT Tokens)
> - Directory Listing, Jackson Default Typing, Servlet Errors, TrustManager

### **A03:2025 – Software Supply Chain Failures**

> - Уязвимые и устаревшие зависимости (Log4j, Spring, Jackson, Commons-Collections, Struts, MySQL, Guava, SnakeYAML, OkHttp)
> - Dependency Confusion / Typosquatting (Repository Order, SNAPSHOT, Untrusted Repositories, Wildcard Versions)
> - Отсутствие проверки целостности (Checksums, GPG Signatures, Gradle Verification, Lock Files)
> - CI/CD Pipeline Security (Secrets in Config, Insecure Scripts, Docker, GitHub Actions, Maven Deploy)
> - SBOM и Visibility (CycloneDX, Dependency-Check, Transitive Dependencies, License Compliance)
> - Runtime Dependency Loading (URLClassLoader, Maven Runtime Resolution, Groovy Grape, Plugins, JavaAgent, OSGi)
> - Build Tool Configuration (Maven Settings, Gradle Wrapper, Maven Enforcer, Init Scripts, Reproducible Builds)

### **A04:2025 – Cryptographic Failures**

> - Слабые алгоритмы хеширования (MD5, SHA1)
> - Слабое шифрование (DES, RC4, Blowfish, ECB)
> - Управление ключами (hardcoded keys, weak key sizes, PBKDF2)
> - TLS/ SSL проблемы (старые версии, отключенная проверка сертификатов)
> - Генерация случайных чисел (Math.random vs SecureRandom)
> - Хранение паролей (plaintext, без соли, BCrypt настройки)
> - Утечка чувствительных данных (логи, исключения, URL)
> - Шифрование БД и файлов
> - HTTP безопасность (Basic Auth, HTTP вместо HTTPS)
> - Управление токенами (JWT, API keys, AWS credentials)
> - Безопасная коммуникация (FTP, Telnet, SMTP)
> - Маскирование данных (PII в логах, toString)
> - Backup и экспорт данных
> - Mobile и API безопасность

### **A05:2025 – Injection (SQL/OS/Expression)**

> - SQL Injection (JDBC, JPA, Hibernate, Spring Data, MyBatis)
> - NoSQL Injection (MongoDB)
> - OS Command Injection
> - LDAP, XPath, XML/ XXE
> - Expression Language (SpEL, OGNL, MVEL, JEXL)
> - Template Injection (FreeMarker, Velocity, Thymeleaf)
> - Log/ Header/ Path Traversal
> - JNDI/ Script/ XSS/ SSRF
> - Email/ Regex/ Format String/ JMX/ CSV/ HTML/ CRLF Injection

### **A06:2025 – Insecure Design**

> - Отсутствие Rate Limiting (REST Endpoints, Authentication, Password Reset, Registration, API Keys, File Upload, Search, Export)
> - Небезопасная бизнес-логика (Missing Business Validation, Idempotency, Price Verification, Quantity Overflow, Discount Reuse, Workflow Skip, Race Conditions, Role Verification, Referral Fraud, Age Verification, Random Number Security, Subscription Tier)
> - Отсутствие CAPTCHA/Bot Protection (Public Forms, Voting, Like Buttons, SMS OTP, Newsletter)
> - Недостаточная изоляция (Shared Sessions, Tenant Isolation, Cache Poisoning, Error Handler Leaks, Admin/User Context, Connection Pool, File Storage)
> - Отсутствие Fail-Safe механизмов (Payment Rollback, Authentication Default Allow, Circuit Breaker, Timeout Configuration, Exception Suppression)
> - Хардкод бизнес-лимитов (Max Amount, Retry Count, Token Expiry, Page Size, Salt Rounds)
> - Отсутствие Audit Trail (Critical Operations, Financial Transactions, Permission Changes, Configuration Changes)
> - Архитектурные недостатки (Synchronous Long Operations, Missing Correlation ID, No Graceful Shutdown)

### **A07:2025 – Authentication Failures**

> - Слабые пароли и учётные данные (Weak Validation, Complexity Regex, Default Credentials, Case-Sensitive Username, Password Contains Username, Password in GET, Credentials in URL, API Key in Query, Password Expiry, Sequential Passwords)
> - Отсутствие/слабая MFA (Sensitive Operations without MFA, Backup Codes Unlimited, TOTP Rate Limiting, SMS OTP Spam, OTP Validity, MFA Enrollment, Remember Device)
> - Управление сессиями (Session Fixation, Session ID in URL, Session Timeout, Logout Invalidation, Concurrent Sessions, Sensitive Data in Session, JWT Expiry, JWT Algorithm None, Refresh Token Rotation, Remember-Me Token Predictable)
> - Защита от Brute Force (Login Rate Limiting, Account Lockout, No Delay After Failed Login, Timing Attacks, Failed Login Logging, CAPTCHA After Failures, Distributed Brute Force)
> - Небезопасное восстановление пароля (Reset Token Predictable, Long Expiry, Without Current Password, Security Questions, Token Reusable, No Notification)
> - Хранение учётных данных (Plaintext Storage, MD5/SHA-1 Hashing, Weak BCrypt Rounds, No Salt, Credentials Logged, API Key Plaintext)
> - Authentication Bypass (Bypassable Checks, SQL Injection, LDAP Injection, Null Check Flaws, Boolean Parameter Auth)
> - Account Enumeration (Different Error Messages, Registration Reveals Users, Password Reset Reveals)
> - OAuth State Parameter, Auto-Login After Registration

### **A08:2025 – Software or Data Integrity Failures**

> - Небезопасная десериализация (ObjectInputStream без Filter, XStream без Security Setup, XMLDecoder User Input, Jackson Default Typing, Kryo без Registration, SnakeYAML Unsafe Constructor, Base64+ObjectInputStream, RMI Registry, readObject без Validation, Hessian без Whitelist, Protostuff Dynamic Schema, ActiveMQ ObjectMessage, Redis Deserialization, Cookie Deserialization, Spring Remoting)
> - Проверка целостности (File Download без Hash, MD5 для Integrity, SHA-1 для Integrity, Missing HMAC на Serialized Data, Trust All Certificates, Hostname Verifier Disabled, Missing Certificate Pinning, XML Signature Not Verified, SAML Signature Bypass, JWT None Algorithm, CRC32 для Security, Weak Random для Integrity Token)
> - Динамическая загрузка классов (Class.forName User Input, URLClassLoader User Input, Reflection Method Invoke, GroovyClassLoader User Code, Dynamic Proxy без Whitelist, Context ClassLoader User Input, Plugin Loading без Signature, Java Agent без Signature, ASM Bytecode User Input)
> - Supply Chain / Зависимости (Maven Repository HTTP, SNAPSHOT in Production, Remote JAR over HTTP, JAR Loading без Code Signing)
> - Обновления без проверки целостности (Auto-Update over HTTP, Update без Signature Verification, Download and Exec без Verify)
> - Целостность данных (Jackson readValue Object/Map, JNDI ObjectFactory User Input, SpEL из Database, Externalized Config без Integrity, Zip Slip on Extract)
> - Скрипты и исполняемый код (ScriptEngine User Code, EL/SpEL из User Input, Spring Expression из Database)

### **A09:2025 – Security Logging & Alerting Failures**

> - Логирование чувствительных данных (Password Plaintext, Token/API Key, Credit Card PAN, PII/Personal Data, Full HTTP Request Body, User Object toString, Exception with Credentials, SQL Query with Values, Private Key Material, Session ID в логах)
> - Log Injection (CRLF Injection, Request Parameter Direct Log, User-Agent без Sanitize, Referer Header, Log4Shell Pattern, Format String Injection)
> - Отсутствие логирования security-событий (Authentication Failure, Successful Login, Authorization Failure, Account Lockout, Password Change, Privilege Escalation, Account Deletion, Data Export, Input Validation Failure, Token Invalidation)
> - Неправильные уровни логирования (Security Event на DEBUG, Critical Event на INFO, Exception Swallowed without Log, System.out вместо Logger, Security Exception Message Only)
> - Audit Log — целостность и полнота (без User Context, без Timestamp, без IP Address, в той же БД, Deletable Audit Log, без Correlation ID)
> - Алертинг и мониторинг (Rate Limit без Alert, Security Event без Metrics, No Logging in Filter Chain, Scheduled Security Job без Logging)
> - Конфигурация логирования (Logging Disabled Globally, Security Package Logging OFF, Log File без Rotation, AsyncAppender Discard Security Events, MDC без User Context, Log Level Change Unprotected)
> - Специфические случаи (First Login без Alert, Certificate Validation Error Silent, MFA Bypass без Log, File Upload без Log, Exception без Context, Suspicious Activity без Alert)

### **A10:2025 – Mishandling of Exceptional Conditions**

> - Раскрытие информации через ответы об ошибках (Stacktrace in HTTP Response, Stacktrace in Response Body, Spring server.error Full Details, SQLException Message Exposed, File Path Disclosed, ClassNotFoundException Exposed, NPE Message in Response, Validation BindingResult Exposed, Exception Cause Chain, Generic ExceptionHandler with getMessage, Request Params in Error Response)
> - Игнорирование исключений (Empty Catch Block, SecurityException Silent, Crypto Exception Returns Default, IOException in Auth Swallowed, InterruptedException без interrupt(), Multiple Exceptions One Catch Obscures)
> - Небезопасное состояние после исключения (Transaction Committed after Exception, Resource Not Closed on Exception, SecurityContext Not Cleared, Lock Not Released in Finally, Session Not Invalidated on Auth Error, Partial File Write, Concurrent State Corrupted)
> - Повторный выброс и оборачивание исключений (AccessDeniedException wrapped as RuntimeException, AuthException wrapped as 500, Rethrow with Sensitive Data, return in Finally Suppresses Exception, Exception in Finally Masks Original)
> - Неверные HTTP статус-коды (Auth Failure returns 200, AccessDenied returns 404, Validation Error returns 500, Rate Limit returns 500 вместо 429)
> - Обработка ошибок в асинхронном контексте (CompletableFuture без exceptionally, Thread без UncaughtExceptionHandler, Executor Submit без Future.get, Scheduled Task без Alerting on Failure)
> - Небезопасные паттерны обработки (Return true on Security Exception, Null Return in loadUserByUsername, Catch java.lang.Error, Double Catch Obscures Security, Break in Loop on Security Check, Exception Timing Oracle)
> - Конфигурация и глобальная обработка (No Global ControllerAdvice, Whitelabel Error Page Enabled, Custom /error с Exception Details, Debug Mode in Production, Missing Security Exception Handlers, server.error.include-stacktrace=always)

***
