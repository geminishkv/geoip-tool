# Release Notes

## v1.1.0

### Общий пул проведенных работ

* Добавлены 6 новых команд: `abuse`, `whois`, `dns`, `recon`, `reverse`, `scan`
* Реализована модульная архитектура — каждая команда в отдельном lib-файле
* Реализован цветной вывод с поддержкой `--no-color` и автоотключением в пайпах
* Добавлен экспорт в машиночитаемые форматы: CSV, TSV, JSONL, JSON (`--format`)
* Реализовано чтение из stdin для пайплайнов (`geoip file -`)
* Добавлена система конфигурации с хранением API-ключей (`~/.config/geoip-tool/config`)
* Реализован автоматический retry при HTTP 429 (rate-limit) с парсингом `Retry-After`
* Добавлен ASCII-баннер и расширенная справка `--help` по всем командам
* Исправлена кросс-платформенная совместимость (Windows / Git Bash / macOS)
* Подготовлена документация: CHANGELOG.md, EXAMPLES.md

### Следующие команды были добавлены:

* **Security & OSINT**
  * `abuse` — проверка IP через AbuseIPDB (score, жалобы, категории, ISP)
  * `whois` — WHOIS lookup через системный `whois` или ARIN REST API (fallback для Windows)
  * `dns` — DNS-разведка: A, AAAA, MX, NS, TXT, SOA, CNAME (через `dig` / `nslookup`)
  * `recon` — полная разведка одной командой (lookup + reverse + dns + whois + abuse + http)

* **Network**
  * `reverse` — Reverse IP lookup через 4 провайдера: HackerTarget, Shodan, crt.sh, PTR
  * `scan` — интеграция с nmap: quick / full / stealth сканирование портов

* **Утилиты**
  * `config` — управление конфигом и API-ключами (set / path / show)

### Следующие глобальные опции были добавлены:

* `--format csv|tsv|jsonl|json` — экспорт в машиночитаемые форматы
* `--output FILE` / `-o FILE` — сохранение вывода в файл (дублируется на экран через `tee`)
* `--no-color` — отключение ANSI-цветов (также поддерживается `NO_COLOR=1` env)

### Следующие улучшения внесены в существующие команды:

* `http` — добавлена опция `--ports` для пробинга на произвольных портах
* `http` — цветные HTTP-статусы: 2xx зелёный, 4xx жёлтый, 5xx красный
* `lookup` — цветной форматированный вывод с метками
* `lookup` / `file` — поддержка stdin piping и batch-экспорт CSV/TSV/JSONL
* Все команды — единообразное цветное оформление заголовков и ошибок

### Исправления

* `http` — HEAD-запросы зависали (10s timeout) — исправлено: `curl -I` вместо `-X HEAD`
* `reverse` (PTR) — некорректный вывод на Windows из-за CP866 nslookup — исправлено: `LC_ALL=C`
* Кеш — `stat -c %Y` не работал на Windows/macOS — исправлено: fallback через `date -r`
* `dns` (TXT) — nslookup не отображал значения TXT-записей — исправлен парсер awk

### Изменённые файлы

| Файл | Тип | Описание |
|------|-----|----------|
| `lib/geoip_core.sh` | Изменён | Цвета, --no-color, --format, config, banner, dispatch |
| `lib/geoip_lookup.sh` | Изменён | Цветной вывод, stdin piping, CSV/TSV/JSONL экспорт |
| `lib/geoip_http.sh` | Изменён | --ports, цветные HTTP-статусы, HEAD fix |
| `lib/geoip_reverse.sh` | Изменён | Цветные заголовки, PTR LC_ALL=C fix |
| `lib/geoip_nmap.sh` | Изменён | nmap интеграция |
| `lib/geoip_abuseipdb.sh` | Новый | Команда `abuse` (AbuseIPDB) |
| `lib/geoip_whois.sh` | Новый | Команда `whois` (CLI + ARIN API) |
| `lib/geoip_dns.sh` | Новый | Команда `dns` (dig / nslookup) |
| `lib/geoip_recon.sh` | Новый | Команда `recon` (оркестрация модулей) |
| `bin/geoip` | Изменён | Подключение новых модулей |
| `CHANGELOG.md` | Изменён | Полный changelog по всем фичам |
| `EXAMPLES.md` | Новый | Примеры вывода команд из терминала |
| `RELEASE_NOTES.md` | Новый | Release notes для GitHub Release |

### Примеры использования

```bash
# Базовый GeoIP lookup
geoip lookup 8.8.8.8

# Полная разведка
geoip recon --full 8.8.8.8

# AbuseIPDB с детальными репортами
geoip abuse --verbose 185.220.101.1

# DNS-разведка
geoip dns --type MX google.com

# WHOIS
geoip whois 8.8.8.8

# HTTP-пробинг на нестандартных портах
geoip http --ports 80,443,8080 --aggressive example.com

# Batch CSV экспорт
geoip --format csv file ips.txt

# Пайплайн через stdin
echo -e "8.8.8.8\n1.1.1.1" | geoip --format jsonl file -

# Reverse IP через Shodan
geoip reverse --reverse-provider shodan 1.1.1.1

# Сканирование портов с GeoIP
geoip scan --with-lookup --top-ports 100 target.com
```

### Дополнение

* Команда `abuse` требует API-ключ: `geoip config set ABUSEIPDB_API_KEY <key>` (бесплатный на abuseipdb.com)
* Команда `scan` требует установленный `nmap` в PATH
* Команда `whois` использует системный `whois` (Linux/macOS) с fallback через ARIN REST API (Windows)
* Команда `dns` использует `dig` (приоритет) или `nslookup` (fallback)
* Цвета автоматически отключаются при перенаправлении вывода в файл или пайп
* Конфиг хранится в `~/.config/geoip-tool/config` (или `$XDG_CONFIG_HOME`), парсится безопасно без `source`

## v1.0.0

* Первый публичный релиз
* Базовые команды: `lookup`, `json`, `file`, `http`
* Поддержка провайдеров: ip-api.com, ipapi.co
* Кеширование ответов с TTL
* Batch-обработка из файла
