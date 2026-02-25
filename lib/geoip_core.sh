#!/usr/bin/env bash
set -euo pipefail

API_BASE="http://ip-api.com/json"
DEFAULT_LANG="ru"
CACHE_DIR="${HOME}/.cache/geoip-tool"

mkdir -p "$CACHE_DIR"

usage() {
  cat <<EOF
geoip - утилита для GeoIP-lookup и проверки IP

Использование:
  geoip [команда] [аргументы]

Команды:
  lookup [IP|host]     GeoIP по IP/ домену (pretty, по умолчанию)
  json   [IP|host]     JSON для пайплайнов
  file   <file>        Lookup по списку IP/ хостов
  http   <IP|host>     Тест HTTP-методов (GET, POST, PUT, DELETE, HEAD, OPTIONS, TRACE)
  help                 Показать справку

Примеры:
  geoip
  geoip lookup 8.8.8.8
  geoip json cloudflare.com
  geoip file examples/ips.txt
  geoip http 1.2.3.4
EOF
}

_cache_key() {
  local key="$1"
  echo "${key//[^A-Za-z0-9._-]/_}"
}

CACHE_TTL_SEC=3600

cache_get() {
  local query="$1"
  local lang="${2:-$DEFAULT_LANG}"
  local key file
  key=$(_cache_key "${query:-_self_}_${lang}")
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
  key=$(_cache_key "${query:-_self_}_${lang}")
  file="${CACHE_DIR}/${key}.json"
  printf '%s\n' "$body" >"$file"
}

_ipapi_request_raw() {
  local query="${1:-}"
  local lang="${2:-$DEFAULT_LANG}"

  local url
  if [[ -z "$query" ]]; then
    url="$API_BASE/?lang=$lang"
  else
    url="$API_BASE/$query?lang=$lang"
  fi

  local response headers body
  response=$(curl -s -D - "$url")
  headers=$(printf '%s\n' "$response" | sed '/^\r\{0,1\}$/q')
  body=$(printf '%s\n' "$response" | sed '1,/^\r\{0,1\}$/d')

  local remaining ttl
  remaining=$(printf '%s\n' "$headers" | awk 'BEGIN{RS="\r\n"} /^X-Rl:/ {print $2}' || true)
  ttl=$(printf '%s\n' "$headers" | awk 'BEGIN{RS="\r\n"} /^X-Ttl:/ {print $2}' || true)

  if [[ -n "$remaining" || -n "$ttl" ]]; then
    >&2 echo "[ip-api] X-Rl=${remaining:-?} X-Ttl=${ttl:-?}"
  fi

  printf '%s\n' "$body"
}

ipapi_request_with_cache() {
  local query="${1:-}"
  local lang="${2:-$DEFAULT_LANG}"

  if cache_get "$query" "$lang" >/dev/null 2>&1; then
    cache_get "$query" "$lang"
    return 0
  fi

  local body
  body=$(_ipapi_request_raw "$query" "$lang")
  if echo "$body" | jq -e '.status == "success"' >/dev/null 2>&1; then
    cache_put "$query" "$lang" "$body"
  fi
  printf '%s\n' "$body"
}

main() {
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