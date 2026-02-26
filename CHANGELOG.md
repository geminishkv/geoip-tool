# Changelog

## [Unreleased] — 2026-02-26

### Added

#### 1. Глобальная опция `--output FILE` / `-o FILE`
Сохранение полного вывода любой команды в файл. Вывод дублируется: и на экран, и в файл (через `tee`).

```bash
geoip -o result.txt lookup 8.8.8.8
geoip --output=scan_results.txt http --aggressive example.com
```

**Файлы:** `lib/geoip_core.sh`

---

#### 2. Автоматический Retry-After при HTTP 429
Если API-провайдер возвращает HTTP 429 (Too Many Requests), утилита автоматически:
- Парсит заголовок `Retry-After` (в секундах)
- Ждёт указанное время (макс. 60 сек, по умолчанию 5 сек)
- Повторяет запрос (до 3 попыток)
- Логирует в stderr: `[rate] HTTP 429 — повтор 1/3 через 5s...`

Конфигурация через переменные `MAX_RETRIES=3`, `DEFAULT_RETRY_AFTER=5`.

**Файлы:** `lib/geoip_core.sh`

---

#### 3. Опция `--ports` для команды `http`
Пробинг HTTP-методов на произвольных портах (не только 80/443).

```bash
geoip http --ports 80,443,8080,8443 example.com
geoip http --ports 3000,5000 --aggressive localhost
```

- Валидация: только числовые значения 1-65535
- Стандартные порты (80 для http, 443 для https) не добавляются в URL
- Работает со всеми режимами: `--auto`, `--http`, `--https`, фиксированный URL

**Файлы:** `lib/geoip_http.sh`

---

#### 4. Команда `reverse` — Reverse IP Lookup
Находит домены/хосты, привязанные к IP-адресу. Поддерживает 4 провайдера:

| Провайдер | API | Ключ | Лимит |
|-----------|-----|------|-------|
| `hackertarget` (default) | api.hackertarget.com | Нет | 20 запросов/день |
| `shodan` | internetdb.shodan.io | Нет | Высокий |
| `crtsh` | crt.sh (Certificate Transparency) | Нет | Без лимита |
| `ptr` | DNS PTR (dig / nslookup) | Нет | Без лимита |

```bash
geoip reverse 8.8.8.8                              # HackerTarget (default)
geoip reverse --reverse-provider shodan 1.1.1.1     # Shodan InternetDB
geoip reverse --reverse-provider crtsh 8.8.8.8      # Certificate Transparency
geoip reverse --reverse-provider ptr 8.8.8.8        # DNS PTR record
geoip reverse --json 8.8.8.8                        # JSON вывод
geoip reverse --reverse-providers                    # Список провайдеров
```

Shodan InternetDB дополнительно показывает открытые порты, уязвимости и CPE.

**Файлы:** `lib/geoip_reverse.sh` (новый), `bin/geoip`, `lib/geoip_core.sh`, `Makefile`

---

#### 5. Команда `scan` — интеграция с nmap
Сканирование портов с помощью nmap с интеграцией в GeoIP lookup.

```bash
geoip scan 192.168.1.0/24                           # Quick scan, top 100 портов
geoip scan --top-ports 1000 target.com              # Top 1000 портов
geoip scan --ports 22,80,443,8080 example.com       # Конкретные порты
geoip scan --scan-type full target.com              # Все 65535 портов
geoip scan --scan-type stealth target.com           # SYN scan (требует sudo)
geoip scan --with-lookup 8.8.8.8                    # + GeoIP для найденных IP
geoip scan --xml-output result.xml target.com       # Сохранить XML nmap
geoip scan --nmap-args "-sV -O" target.com          # Доп. аргументы nmap
```

Типы сканирования:
- `quick` (default) — TCP connect, `--top-ports N`
- `full` — TCP connect, все 65535 портов
- `stealth` — SYN scan (требует root/sudo)

Требует установленный `nmap` в PATH. При отсутствии выдаёт инструкции по установке.

**Файлы:** `lib/geoip_nmap.sh` (новый), `bin/geoip`, `lib/geoip_core.sh`, `Makefile`

---

### Fixed

#### Кросс-платформенная совместимость (Windows / Git Bash)
- `stat -c %Y` заменён на `date -r` с fallback для корректной работы кеша на Windows/macOS
- PTR-провайдер в `reverse`: парсинг nslookup работает на Windows (локализованный вывод) и Linux
- Проверка nmap вынесена после парсинга аргументов — `--help` работает без установленного nmap

---

### Изменённые файлы

| Файл | Тип | Описание |
|------|-----|----------|
| `lib/geoip_core.sh` | Изменён | --output/-o, retry 429, dispatch reverse/scan |
| `lib/geoip_http.sh` | Изменён | --ports для HTTP пробинга |
| `lib/geoip_reverse.sh` | Новый | Команда reverse (4 провайдера) |
| `lib/geoip_nmap.sh` | Новый | Команда scan (nmap интеграция) |
| `bin/geoip` | Изменён | Подключение новых модулей |
| `Makefile` | Изменён | Установка новых lib-файлов |
