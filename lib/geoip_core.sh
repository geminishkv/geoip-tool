#!/usr/bin/env bash
set -euo pipefail

DEFAULT_LANG="ru"
CACHE_DIR="${HOME}/.cache/geoip-tool"
CACHE_TTL_SEC=3600
MAX_RETRIES=3
DEFAULT_RETRY_AFTER=5

PROVIDER_DEFAULT="${GEOIP_PROVIDER:-ip-api}"
PROVIDER="$PROVIDER_DEFAULT"
OUTPUT_FILE=""

mkdir -p "$CACHE_DIR"

usage() {
  cat <<'EOF'
geoip - утилита для GeoIP-lookup и проверки целей

Использование:
  geoip [--provider NAME] [--output FILE] <command> [args...]
  geoip --providers
  geoip --help

Глобальные опции:
  --providers              Показать список провайдеров
  --provider NAME          Выбрать провайдера (по умолчанию ip-api)
  --provider=NAME          Выбрать провайдера (по умолчанию ip-api)
  --output FILE, -o FILE   Сохранить вывод в файл (stdout дублируется)
  -h, --help               Справка

Команды:
  lookup [IP|host]         GeoIP (pretty). Если без аргумента — для текущего IP
  json   [IP|host]         Сырой JSON (удобно для jq/ пайплайнов)
  file   <file>            Батч-lookup (по строке IP/ host на строку)
  http   [opts] <target>   Пробинг HTTP-методов (см. geoip http --help)
  reverse [opts] <IP>      Reverse IP lookup — домены на IP (см. geoip reverse --help)
  scan    [opts] <target>  nmap-сканирование портов (требует nmap, см. geoip scan --help)
  help                     Показать справку

Примеры:
  geoip lookup 8.8.8.8
  geoip json 1.1.1.1 | jq .
  geoip --provider ipapi-co lookup 8.8.8.8
  geoip http --help
  geoip reverse 8.8.8.8
  geoip scan --top-ports 10 8.8.8.8
EOF
}

providers_list() {
  cat <<'EOF'
Supported providers:
  ip-api     (default)  http://ip-api.com/json/<query>?lang=...
  ipapi-co              https://ipapi.co/<query>/json/
EOF
}

_cache_key() {
  local key="$1"
  echo "${key//[^A-Za-z0-9._-]/_}"
}

cache_get() {
  local query="$1"
  local lang="${2:-$DEFAULT_LANG}"
  local key file
  key=$(_cache_key "${PROVIDER}_${query:-_self_}_${lang}")
  file="${CACHE_DIR}/${key}.json"

  if [[ -f "$file" ]]; then
    local now ts age
    now=$(date +%s)
    ts=$(date -r "$file" +%s 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0)
    age=$((now - ts))
    if (( age <= CACHE_TTL_SEC )); then
      cat "$file"
      return 0
    fi
  fi
  return 1
}

cache_put() {
  local query="$1"
  local lang="${2:-$DEFAULT_LANG}"
  local body="$3"
  local key file
  key=$(_cache_key "${PROVIDER}_${query:-_self_}_${lang}")
  file="${CACHE_DIR}/${key}.json"
  printf '%s\n' "$body" >"$file"
}

_http_get_with_headers() {
  local url="$1"
  local attempt=0

  while (( attempt <= MAX_RETRIES )); do
    local response headers body
    response=$(curl -s -D - "$url")
    headers=$(printf '%s\n' "$response" | sed '/^\r\{0,1\}$/q')
    body=$(printf '%s\n' "$response" | sed '1,/^\r\{0,1\}$/d')

    local remaining ttl
    remaining=$(printf '%s\n' "$headers" | awk 'BEGIN{RS="\r\n"} /^X-Rl:/ {print $2}' || true)
    ttl=$(printf '%s\n' "$headers" | awk 'BEGIN{RS="\r\n"} /^X-Ttl:/ {print $2}' || true)
    if [[ -n "$remaining" || -n "$ttl" ]]; then
      >&2 echo "[rate] X-Rl=${remaining:-?} X-Ttl=${ttl:-?}"
    fi

    local http_status
    http_status=$(printf '%s\n' "$headers" | head -n 1 | awk '{print $2}' || true)

    if [[ "$http_status" == "429" ]]; then
      attempt=$((attempt + 1))
      if (( attempt > MAX_RETRIES )); then
        >&2 echo "[rate] HTTP 429 после $MAX_RETRIES попыток, сдаёмся"
        printf '%s\n' "$body"
        return 1
      fi

      local retry_after
      retry_after=$(printf '%s\n' "$headers" | awk 'BEGIN{RS="\r\n"} tolower($0) ~ /^retry-after:/ {gsub(/[^0-9]/,"",$2); print $2; exit}' || true)
      retry_after="${retry_after:-$DEFAULT_RETRY_AFTER}"
      if (( retry_after > 60 )); then
        retry_after=60
      fi

      >&2 echo "[rate] HTTP 429 — повтор $attempt/$MAX_RETRIES через ${retry_after}s..."
      sleep "$retry_after"
      continue
    fi

    printf '%s\n' "$body"
    return 0
  done
}

provider_request_raw() {
  local query="${1:-}"
  local lang="${2:-$DEFAULT_LANG}"

  case "$PROVIDER" in
    ip-api)
      local url
      if [[ -z "$query" ]]; then
        url="http://ip-api.com/json/?lang=$lang"
      else
        url="http://ip-api.com/json/$query?lang=$lang"
      fi
      _http_get_with_headers "$url"
      ;;
    ipapi-co)
      local url
      if [[ -z "$query" ]]; then
        url="https://ipapi.co/json/"
      else
        url="https://ipapi.co/$query/json/"
      fi
      _http_get_with_headers "$url"
      ;;
    *)
      echo "ERROR: unknown provider '$PROVIDER' (см. --providers)" >&2
      return 2
      ;;
  esac
}

provider_request_with_cache() {
  local query="${1:-}"
  local lang="${2:-$DEFAULT_LANG}"

  if cache_get "$query" "$lang" >/dev/null 2>&1; then
    cache_get "$query" "$lang"
    return 0
  fi

  local body
  if ! body=$(provider_request_raw "$query" "$lang"); then
    >&2 echo "ERROR: запрос к провайдеру не удался"
    return 1
  fi

  if echo "$body" | jq -e 'type=="object"' >/dev/null 2>&1; then
    cache_put "$query" "$lang" "$body"
  fi

  printf '%s\n' "$body"
}

main() {
  while [[ "${1:-}" == -* ]]; do
    case "$1" in
      --providers)
        providers_list
        return 0
        ;;
      --provider)
        shift || true
        PROVIDER="${1:-}"
        if [[ -z "$PROVIDER" ]]; then
          echo "ERROR: --provider требует имя (см. --providers)" >&2
          return 2
        fi
        ;;
      --provider=*)
        PROVIDER="${1#*=}"
        ;;
      --output|-o)
        shift || true
        OUTPUT_FILE="${1:-}"
        if [[ -z "$OUTPUT_FILE" ]]; then
          echo "ERROR: --output/-o требует путь к файлу" >&2
          return 2
        fi
        ;;
      --output=*)
        OUTPUT_FILE="${1#*=}"
        ;;
      --help|-h)
        usage
        return 0
        ;;
      *)
        echo "ERROR: unknown option '$1' (см. --help)" >&2
        return 2
        ;;
    esac
    shift || true
  done

  local cmd="${1:-lookup}"
  shift || true

  _dispatch_cmd() {
    case "$1" in
      lookup)  shift; cmd_lookup "$@";;
      json)    shift; cmd_json "$@";;
      file)    shift; cmd_file "$@";;
      http)    shift; cmd_http "$@";;
      reverse) shift; cmd_reverse "$@";;
      scan)    shift; cmd_scan "$@";;
      help|-h|--help) usage;;
      *) echo "Unknown command: $1"; usage; exit 1;;
    esac
  }

  if [[ -n "$OUTPUT_FILE" ]]; then
    _dispatch_cmd "$cmd" "$@" | tee "$OUTPUT_FILE"
  else
    _dispatch_cmd "$cmd" "$@"
  fi
}