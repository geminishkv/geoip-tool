#!/usr/bin/env bash
set -euo pipefail

DEFAULT_LANG="ru"
CACHE_DIR="${HOME}/.cache/geoip-tool"
CACHE_TTL_SEC=3600

PROVIDER_DEFAULT="${GEOIP_PROVIDER:-ip-api}"
PROVIDER="$PROVIDER_DEFAULT"

mkdir -p "$CACHE_DIR"

usage() {
  cat <<'EOF'
geoip - утилита для GeoIP-lookup и проверки целей

Использование:
  geoip [--provider NAME] [команда] [аргументы]
  geoip --providers

Глобальные опции:
  --providers                 Показать список провайдеров
  --provider NAME             Выбрать провайдера (по умолчанию ip-api)
  --provider=NAME             Выбрать провайдера (по умолчанию ip-api)
  -h, --help                  Справка

Команды:
  lookup [IP|host]            GeoIP (pretty, по умолчанию)
  json   [IP|host]            JSON для пайплайнов
  file   <file>               Lookup по списку IP/хостов
  http   <target> [опции]     HTTP-методы (см. geoip http --help)
  help                        Показать справку

Примеры:
  geoip
  geoip lookup 8.8.8.8
  geoip json cloudflare.com | jq .
  geoip file examples/ips.txt
  geoip --provider ipapi-co lookup 8.8.8.8
  geoip http target.example.com --https --aggressive
EOF
}

providers_list() {
  cat <<'EOF'
Supported providers:
  ip-api     (default)  http://ip-api.com/json/<query>   (free: 45 req/min, HTTP only, X-Rl/X-Ttl headers)
  ipapi-co              https://ipapi.co/<query>/json/   (usually HTTPS)
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
    ts=$(stat -c %Y "$file" 2>/dev/null || echo 0)
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

  printf '%s\n' "$body"
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
  body=$(provider_request_raw "$query" "$lang")

  if echo "$body" | jq -e 'type=="object"' >/dev/null 2>&1; then
    cache_put "$query" "$lang" "$body"
  fi

  printf '%s\n' "$body"
}

main() {
  while [[ "${1:-}" == --* ]]; do
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

  case "$cmd" in
    lookup) cmd_lookup "$@";;
    json)   cmd_json "$@";;
    file)   cmd_file "$@";;
    http)   cmd_http "$@";;
    help|-h|--help) usage;;
    *) echo "Unknown command: $cmd"; usage; exit 1;;
  esac
}