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
OUTPUT_FORMAT="pretty"

# Цвета (отключаются через --no-color или NO_COLOR env)
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_RED=$'\033[0;31m'
  C_GREEN=$'\033[0;32m'
  C_YELLOW=$'\033[0;33m'
  C_CYAN=$'\033[0;36m'
  C_MAGENTA=$'\033[0;35m'
  C_DIM=$'\033[2m'
else
  C_RESET='' C_BOLD='' C_RED='' C_GREEN='' C_YELLOW='' C_CYAN='' C_MAGENTA='' C_DIM=''
fi

_disable_colors() {
  C_RESET='' C_BOLD='' C_RED='' C_GREEN='' C_YELLOW='' C_CYAN='' C_MAGENTA='' C_DIM=''
}

mkdir -p "$CACHE_DIR"

# Конфиг (~/.config/geoip-tool/config)
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/geoip-tool"
CONFIG_FILE="$CONFIG_DIR/config"
if [[ -f "$CONFIG_FILE" ]]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    key=$(echo "$key" | tr -d '[:space:]')
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    export "$key=$value" 2>/dev/null || true
  done < "$CONFIG_FILE"
fi

cmd_config() {
  local subcmd="${1:-}"

  case "$subcmd" in
    path)
      echo "$CONFIG_FILE"
      ;;
    set)
      local key="${2:-}"
      local val="${3:-}"
      if [[ -z "$key" || -z "$val" ]]; then
        echo "Usage: geoip config set KEY VALUE" >&2
        return 2
      fi
      mkdir -p "$CONFIG_DIR"
      # Удалить старую запись если есть, добавить новую
      if [[ -f "$CONFIG_FILE" ]]; then
        local tmp
        tmp=$(grep -v "^${key}=" "$CONFIG_FILE" 2>/dev/null || true)
        printf '%s\n' "$tmp" > "$CONFIG_FILE"
      fi
      echo "${key}=${val}" >> "$CONFIG_FILE"
      echo "OK: ${key} сохранён в $CONFIG_FILE"
      ;;
    "")
      if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "Конфиг не найден: $CONFIG_FILE"
        echo "Создайте через: geoip config set KEY VALUE"
        return 0
      fi
      echo "=== $CONFIG_FILE ==="
      while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        key=$(echo "$key" | tr -d '[:space:]')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        # Маскируем значения ключей (показываем первые 3 символа)
        if [[ ${#value} -gt 6 ]]; then
          local masked="${value:0:3}***"
        else
          local masked="***"
        fi
        echo "$key=$masked"
      done < "$CONFIG_FILE"
      ;;
    *)
      echo "Usage: geoip config [set KEY VALUE | path]" >&2
      return 2
      ;;
  esac
}

_banner() {
  printf '%b\n' "${C_CYAN}"
  cat <<'LOGO'
   ██████╗ ███████╗ ██████╗ ██╗██████╗     ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗
  ██╔════╝ ██╔════╝██╔═══██╗██║██╔══██╗    ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║
  ██║  ███╗█████╗  ██║   ██║██║██████╔╝    ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║
  ██║   ██║██╔══╝  ██║   ██║██║██╔═══╝     ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║
  ╚██████╔╝███████╗╚██████╔╝██║██║         ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║
   ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝╚═╝         ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝
LOGO
  printf '%b\n' "  ${C_DIM}v1.0  ·  GeoIP Recon & OSINT Toolkit${C_RESET}"
  echo ""
}

_footer() {
  printf '%b\n' "${C_CYAN}"
  cat <<'LOGO'
   █████╗ ██████╗ ██████╗ ███████╗███████╗ ██████╗████████╗ █████╗
  ██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔════╝██╔════╝╚══██╔══╝██╔══██╗
  ███████║██████╔╝██████╔╝███████╗█████╗  ██║        ██║   ███████║
  ██╔══██║██╔═══╝ ██╔═══╝ ╚════██║██╔══╝  ██║        ██║   ██╔══██║
  ██║  ██║██║     ██║     ███████║███████╗╚██████╗   ██║   ██║  ██║
  ╚═╝  ╚═╝╚═╝     ╚═╝     ╚══════╝╚══════╝ ╚═════╝   ╚═╝   ╚═╝  ╚═╝
LOGO
  printf '%b\n' "${C_RESET}"
}

# Хелперы для стилизации --help
_h() {
  printf '\n%b\n' "${C_MAGENTA}━━━ $1 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
}

_opt() {
  printf "  ${C_CYAN}%-27s${C_RESET} %s\n" "$1" "$2"
}

_exm() {
  printf "  ${C_DIM}%s${C_RESET}\n" "$1"
}

usage() {
  _banner
  printf "  ${C_DIM}geoip - утилита для GeoIP-lookup и проверки целей${C_RESET}\n"

  _h "Использование"
  _exm "geoip [--provider NAME] [--output FILE] <command> [args...]"
  _exm "geoip --providers"
  _exm "geoip --help"

  _h "Глобальные опции"
  _opt "--providers" "Показать список провайдеров"
  _opt "--provider NAME" "Выбрать провайдера (по умолчанию ip-api)"
  _opt "--output FILE, -o FILE" "Сохранить вывод в файл (stdout дублируется)"
  _opt "--format FORMAT" "Формат: pretty, json, jsonl, csv, tsv"
  _opt "--no-color" "Отключить цветной вывод"
  _opt "-h, --help" "Справка"

  _h "Lookup & Export"
  _opt "lookup [IP|host]" "GeoIP lookup (без аргумента — текущий IP)"
  _opt "json   [IP|host]" "Сырой JSON (для jq / пайплайнов)"
  _opt "file   <file|->" "Батч-lookup (IP/host на строку, - = stdin)"

  _h "Network & Recon"
  _opt "http   [opts] <target>" "Пробинг HTTP-методов (см. geoip http --help)"
  _opt "reverse [opts] <IP>" "Reverse IP lookup (см. geoip reverse --help)"
  _opt "scan   [opts] <target>" "nmap-сканирование (см. geoip scan --help)"
  _opt "recon  [opts] <target>" "Полная разведка (см. geoip recon --help)"

  _h "OSINT"
  _opt "abuse  [opts] <IP>" "AbuseIPDB (см. geoip abuse --help)"
  _opt "whois  [opts] <IP|host>" "WHOIS lookup (см. geoip whois --help)"
  _opt "dns    [opts] <домен>" "DNS-разведка (см. geoip dns --help)"

  _h "Утилиты"
  _opt "config [set KEY VAL]" "Управление конфигом и API-ключами"
  _opt "help" "Показать справку"

  _h "Примеры"
  _exm "geoip lookup 8.8.8.8"
  _exm "geoip json 1.1.1.1 | jq ."
  _exm "geoip --format csv file ips.txt"
  _exm "geoip http --aggressive example.com"
  _exm "geoip recon --full 8.8.8.8"
  _exm "geoip dns --type MX google.com"
  _exm "geoip abuse --verbose 185.220.101.1"
  echo ""
  _footer
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
      --no-color)
        _disable_colors
        ;;
      --format)
        shift || true
        OUTPUT_FORMAT="${1:-pretty}"
        case "$OUTPUT_FORMAT" in
          pretty|json|jsonl|csv|tsv) ;;
          *) echo "ERROR: неизвестный формат '$OUTPUT_FORMAT' (pretty, json, jsonl, csv, tsv)" >&2; return 2 ;;
        esac
        ;;
      --format=*)
        OUTPUT_FORMAT="${1#*=}"
        case "$OUTPUT_FORMAT" in
          pretty|json|jsonl|csv|tsv) ;;
          *) echo "ERROR: неизвестный формат '$OUTPUT_FORMAT' (pretty, json, jsonl, csv, tsv)" >&2; return 2 ;;
        esac
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
      abuse)   shift; cmd_abuse "$@";;
      whois)   shift; cmd_whois "$@";;
      dns)     shift; cmd_dns "$@";;
      recon)   shift; cmd_recon "$@";;
      config)  shift; cmd_config "$@";;
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