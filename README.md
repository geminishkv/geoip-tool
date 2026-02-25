<div align="center"><h1><a id="intro"> GeoIP-lookup check for IP.  </a><br></h1></div>

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

## **Возможности**

* geoip json 1.1.1.1 | jq '.' - для JSON формата
* geoip file examples/ips.txt - на таргет
* geoip http 1.2.3.4 - методы
* geoip http target.example.com - на таргет методы
* кэш  ~/.cache/geoip-tool  с JSON по IP

- добавляет вкладку `GeoIP` в Message Editor;
- для каждого HTTP-запроса берет host;
- вызывает локальную утилиту `geoip json <host>`;
- отображает ответ (JSON) во вкладке.

* Чтобы не тянуть ip-api напрямую из Burp (TLS, ToS, лимиты и пр.), делаем так:

> - Jython‑расширение в Burp
> - перехватывает хосты из HTTP‑трафика;
> - вызывает локальную утилиту  geoip json <host>  как подпроцесс;
> - читает JSON из stdout;
> - показывает результат в отдельной вкладке «GeoIP» для выбранного запроса.
> - вся ответственность за взаимодействие с ip-api лежит на  geoip ;
> - кэш и лимиты контролируются в одном месте.

* Заголовки X-Rl и X-Ttl (для контроля лимитов в Burp) в stderr `_ipapi_request_raw`:

```bash
remaining=$(printf '%s\n' "$headers" | awk 'BEGIN{RS="\r\n"} /^X-Rl:/ {print $2}' || true)
ttl=$(printf '%s\n' "$headers" | awk 'BEGIN{RS="\r\n"} /^X-Ttl:/ {print $2}' || true)

if [[ -n "$remaining" || -n "$ttl" ]]; then
  >&2 echo "[ip-api] X-Rl=${remaining:-?} X-Ttl=${ttl:-?}"
fi
```

***

## **Tutorial**

### Преднастройка

#### GitHub Release

```bash
$ curl -L https://github.com/geminishkv/geoip-tool/archive/refs/tags/v0.1.0.tar.gz -o geoip-tool-v0.1.0.tar.gz
$ tar xzf geoip-tool-v0.1.0.tar.gz
$ cd geoip-tool-0.1.0
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

### Manual workflow

***

## **Troubleshooting**

С точки зрения безопасности и юридики:

- Не дергаем ip-api напрямую из Burp/DAST:  
  вся логика общения с внешним сервисом сосредоточена в CLI‑утилите `geoip`.
- Есть:
  - кэш с TTL (уменьшает нагрузку и риск выбить лимиты);  
  - логирование заголовков X-Rl/X-Ttl (можно отслеживать лимит);[1]
  - явное описание ограничений ip-api в README и примерах;[2]
  - мягкий троттлинг в батч‑режиме.
- Проект разделен на модули (`lib/…`), что упрощает дальнейшее развитие и ревью кода.

Такой подход:

- безопасен (нет лишних внешних запросов из Burp, всё прозрачно через локальный процесс);  
- юридически чище (пользователь явно видит ToS/лимиты в README);  
- удобен для дальнейшего расширения (можно добавить другие GeoIP‑провайдеры или переключатель).

Если хочешь, могу дополнительно:

- добавить флаг `--provider` (на будущее — для других сервисов);  
- сделать небольшой `tests/` с простыми bash‑тестами (проверка парсинга кэша, работы модулей без реального HTTP).


***

## **Структура репозитория**

```bash
.

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

* 

***

Copyright (c) 2026 Elijah S Shmakov

![Logo](assets/logotypemd.jpg)
