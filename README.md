<div align="center"><h1><a id="intro"> GeoIP-lookup check for IP </a><br></h1></div>

![Repo Size](https://img.shields.io/github/repo-size/geminishkv/geoip-tool)
![License](https://img.shields.io/github/license/geminishkv/geoip-tool)
![Status](https://img.shields.io/badge/status-active-success)
![Contributor Badge](https://img.shields.io/badge/Contributor-%D0%A8%D0%BC%D0%B0%D0%BA%D0%BE%D0%B2_%D0%98._%D0%A1.-8b9aff?style=flat)
![Contributors](https://img.shields.io/github/contributors/geminishkv/geoip-tool)
![Open pull requests](https://img.shields.io/github/issues-pr/geminishkv/geoip-tool)
![Commit Activity](https://img.shields.io/github/commit-activity/m/geminishkv/geoip-tool)
![Last commit](https://img.shields.io/github/last-commit/geminishkv/geoip-tool/main?style=flat-square&color=blue)

***

<br>Салют :wave:,</br>
Этот проект является мини‑утилитой для GeoIP‑lookup из терминала и обогащения данных как плагина для BurpSuit, на сейчас это пока костыльный вариант, который будут допиливаться далее. Работает через `curl + jq` и бесплатный API **ip-api.com** (без ключа), а также с ipapi-co провайдером.

## **Возможности**

* GeoIP lookup (pretty) по IP/ домену или по вашему текущему IP (включая ipapi-co)
* JSON‑режим для пайплайнов
* Батч‑режим по списку целей из файла
* Режим чекапа `http`: пробует методы `GET/ POST/ PUT/ DELETE/ HEAD/ OPTIONS/ TRACE`. Если на цели нет сервиса, либо порт 80 закрыт, то curl вернёт ошибку соединения
* Кэширование ответов в `~/.cache/geoip-tool` (уменьшает количество запросов к API):

> - Хранится в `~/.cache/geoip-tool` - JSON‑файлы по ключу target и lang
> - TTL кэша задаётся в `geoip_core.sh` (CACHE_TTL_SEC)

* Интеграция с Burp Suite через расширение: вкладка `GeoIP` для запросов, данные берутся через локальную команду `geoip json`

> - BurpSuit - Extender - Options - Python Environment - укажите путь к JAR
> - Extensions - Add: Extension type: Python - Extension file: examples/burp-extension/GeoIpTab.py

* Логирование заголовков X-Rl/X-Ttl (можно отслеживать лимит)
* Троттлинг
* Заголовки X-Rl и X-Ttl (для контроля лимитов в Burp) в stderr `_ipapi_request_raw`:

```bash
remaining=$(printf '%s\n' "$headers" | awk 'BEGIN{RS="\r\n"} /^X-Rl:/ {print $2}' || true)
ttl=$(printf '%s\n' "$headers" | awk 'BEGIN{RS="\r\n"} /^X-Ttl:/ {print $2}' || true)

if [[ -n "$remaining" || -n "$ttl" ]]; then
  >&2 echo "[ip-api] X-Rl=${remaining:-?} X-Ttl=${ttl:-?}"
fi
```

***

## Материалы

### Основной список команд


![help](assets/help.jpg)

### Cписок команд http

![http_help](assets/http_help.jpg)

### Пример с http

![http_exmpl](assets/exmpl.jpg)

***

## **Tutorial**

### Преднастройка

#### GHCR

```bash
docker run --rm ghcr.io/geminishkv/geoip-tool:v0.1.6 --help
docker run --rm ghcr.io/geminishkv/geoip-tool:v0.1.6 lookup 8.8.8.8
docker run --rm -e GEOIP_PROVIDER=ipapi-co ghcr.io/geminishkv/geoip-tool:v0.1.6 json 1.1.1.1
```

#### GitHub Release

```bash
$ curl -L https://github.com/geminishkv/geoip-tool/archive/refs/tags/v0.1.6.tar.gz -o geoip-tool-v0.1.6.tar.gz
$ tar xzf geoip-tool-v0.1.6.tar.gz
$ cd geoip-tool-0.1.6
$ sudo make install
```

#### From repo

```bash
$ git clone https://github.com/geminishkv/geoip-tool.git
$ cd geoip-tool
$ sudo make install
```

### Testing

```bash
$ bash <(curl -fsSL https://raw.githubusercontent.com/geminishkv/geoip-tool/main/bin/geoip) lookup 8.8.8.8
```

### Manual

```bash
$ geoip json 1.1.1.1 | jq '.' # для JSON формата
$ geoip file examples/ips.txt # на таргет
$ geoip --provider ipapi-co json <ip>
$ geoip http example.com
$ geoip http example.com --path /admin
$ geoip http example.com --https --follow
$ geoip http example.com --auto --aggressive
$ geoip http example.com --methods GET,HEAD,OPTIONS,TRACE
```

***

## **Структура репозитория**

```bash
.
├── assets
│   ├── exmpl.jpg
│   ├── help.jpg
│   ├── http_help.jpg
│   └── logotypemd.jpg
├── bin
│   └── geoip
├── CONTRIBUTING.md
├── Dockerfile
├── examples
│   ├── burp-extension
│   │   └── GeoIpTab.py
│   └── ips.txt
├── lib
│   ├── geoip_core.sh
│   ├── geoip_http.sh
│   └── geoip_lookup.sh
├── LICENSE.md
├── Makefile
├── NOTICE.md
├── README.md
└── SECURITY.md
```

## Ограничения и юридическая информация

Этот инструмент использует бесплатный JSON-API [ip-api.com](http://ip-api.com):
  - до **45 запросов в минуту** с одного IP; при превышении возможен HTTP 429 и временная блокировка
  - только HTTP (без HTTPS)
  - только **некоммерческое использование**, см. [Terms of Service / Privacy Policy](http://ip-api.com/docs/legal)

**Вы обязаны:**

- соблюдать лимиты запросов (`sleep` и кэш `~/.cache/geoip-tool`)
- не использовать сервис в коммерческих продуктах/ сервисах без перехода на Pro-тариф
- ознакомиться с актуальными условиями на сайте [ip-api.com](http://ip-api.com) перед использованием

Авторы **geoip-tool** не несут ответственности за любые последствия нарушения условий [ip-api.com](http://ip-api.com). или локального законодательства.

***

## **Refs**

* [ip-api JSON API docs](https://ip-api.com/docs/api:json)
* [Rate limit headers X-Rl / X-Ttl](https://ip-api.com/docs/unban)
* [ip-api ToS / Privacy Policy (free usage terms)](https://ip-api.com/docs/legal)

***

Copyright (c) 2026 Elijah S Shmakov

![Logo](assets/logotypemd.jpg)
