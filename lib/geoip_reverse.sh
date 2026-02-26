#!/usr/bin/env bash
set -euo pipefail

REVERSE_PROVIDER="${GEOIP_REVERSE_PROVIDER:-hackertarget}"

_cmd_reverse_help() {
  cat <<'EOF'
Использование:
  geoip reverse [опции] <IP>

Опции:
  --reverse-provider NAME   Провайдер для reverse lookup
                            (hackertarget, shodan, crtsh, ptr)
  --reverse-providers       Показать список провайдеров reverse lookup
  --json                    Вывод в JSON формате
  -h, --help                Справка

Провайдеры:
  hackertarget  (default)  HackerTarget API (20 запросов/день, без ключа)
  shodan                   Shodan InternetDB (бесплатно, hostnames+ports+vulns)
  crtsh                    crt.sh Certificate Transparency (SSL-сертификаты)
  ptr                      DNS PTR запись (dig -x / nslookup, без внешнего API)

Примеры:
  geoip reverse 8.8.8.8
  geoip reverse --reverse-provider shodan 1.1.1.1
  geoip reverse --json 8.8.8.8
EOF
}

_reverse_providers_list() {
  cat <<'EOF'
Reverse lookup providers:
  hackertarget  (default)  https://api.hackertarget.com/reverseiplookup/
  shodan                   https://internetdb.shodan.io/
  crtsh                    https://crt.sh/ (Certificate Transparency)
  ptr                      DNS PTR record (dig -x / nslookup)
EOF
}

_reverse_hackertarget() {
  local ip="$1"
  local url="https://api.hackertarget.com/reverseiplookup/?q=${ip}"
  local body
  body=$(curl -sS --max-time 15 "$url")

  if [[ "$body" == error* ]] || [[ "$body" == "API count exceeded"* ]]; then
    >&2 echo "ERROR: HackerTarget: $body"
    return 1
  fi

  if [[ "$body" == "No records found"* ]] || [[ -z "$body" ]]; then
    >&2 echo "[reverse] Домены не найдены для $ip"
    return 0
  fi

  printf '%s\n' "$body"
}

_reverse_shodan() {
  local ip="$1"
  local url="https://internetdb.shodan.io/${ip}"
  local body
  body=$(curl -sS --max-time 15 "$url")

  if ! echo "$body" | jq -e 'type=="object"' >/dev/null 2>&1; then
    >&2 echo "ERROR: Shodan InternetDB — невалидный JSON"
    return 1
  fi

  local detail
  detail=$(echo "$body" | jq -r '.detail // empty')
  if [[ -n "$detail" ]]; then
    >&2 echo "ERROR: Shodan InternetDB: $detail"
    return 1
  fi

  printf '%s\n' "$body"
}

_reverse_crtsh() {
  local ip="$1"
  local url="https://crt.sh/?q=${ip}&output=json"
  local body
  body=$(curl -sS --max-time 30 "$url")

  if ! echo "$body" | jq -e 'type=="array"' >/dev/null 2>&1; then
    >&2 echo "ERROR: crt.sh — невалидный JSON"
    return 1
  fi

  printf '%s\n' "$body"
}

_reverse_ptr() {
  local ip="$1"

  if command -v dig &>/dev/null; then
    local result
    result=$(dig -x "$ip" +short 2>/dev/null | sed 's/\.$//')
    if [[ -n "$result" ]]; then
      printf '%s\n' "$result"
    else
      >&2 echo "[reverse] PTR-запись не найдена для $ip"
    fi
    return 0
  fi

  if command -v nslookup &>/dev/null; then
    local result
    # Parse nslookup output: extract hostname from PTR response
    # Works on Linux ("name = dns.google") and Windows ("Name: dns.google" / localized)
    result=$(nslookup "$ip" 2>/dev/null | awk '
      /name =/ { sub(/\.$/,"",$NF); print $NF; found=1; exit }
      /^[[:space:]]*$/ { block++ }
      block>=1 && !found && /:[[:space:]]/ && !/[Aa]ddress/ {
        sub(/^[^:]*:[[:space:]]*/,""); gsub(/[[:space:]]*$/,"")
        sub(/\.$/,"")
        if (length>0) { print; found=1; exit }
      }
    ')
    if [[ -n "$result" ]]; then
      printf '%s\n' "$result"
    else
      >&2 echo "[reverse] PTR-запись не найдена для $ip"
    fi
    return 0
  fi

  >&2 echo "ERROR: ни dig, ни nslookup не найдены в PATH"
  return 1
}

cmd_reverse() {
  local json_mode=0
  local target=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _cmd_reverse_help
        return 0
        ;;
      --reverse-provider)
        shift
        REVERSE_PROVIDER="${1:-hackertarget}"
        shift
        ;;
      --reverse-provider=*)
        REVERSE_PROVIDER="${1#*=}"
        shift
        ;;
      --reverse-providers)
        _reverse_providers_list
        return 0
        ;;
      --json)
        json_mode=1
        shift
        ;;
      --)
        shift; break ;;
      --*)
        echo "Неизвестная опция: $1" >&2
        _cmd_reverse_help
        return 2
        ;;
      *)
        if [[ -z "$target" ]]; then
          target="$1"
          shift
        else
          echo "Лишний аргумент: $1" >&2
          _cmd_reverse_help
          return 2
        fi
        ;;
    esac
  done

  if [[ -z "$target" ]]; then
    >&2 echo "ERROR: необходим IP-адрес"
    _cmd_reverse_help
    return 2
  fi

  case "$REVERSE_PROVIDER" in
    hackertarget)
      local domains
      domains=$(_reverse_hackertarget "$target") || return $?
      if [[ "$json_mode" == "1" ]]; then
        printf '%s\n' "$domains" | jq -R -s 'split("\n") | map(select(length > 0))'
      else
        echo "=== Reverse IP Lookup: $target (HackerTarget) ==="
        if [[ -n "$domains" ]]; then
          printf '%s\n' "$domains"
        fi
      fi
      ;;
    shodan)
      local body
      body=$(_reverse_shodan "$target") || return $?
      if [[ "$json_mode" == "1" ]]; then
        printf '%s\n' "$body"
      else
        echo "=== Reverse IP Lookup: $target (Shodan InternetDB) ==="
        echo ""
        echo "Hostnames:"
        echo "$body" | jq -r '.hostnames[]? // empty' | sed 's/^/  /'
        echo ""
        echo "Open Ports:"
        echo "$body" | jq -r '.ports[]? // empty' | sed 's/^/  /'
        echo ""
        echo "Vulns:"
        echo "$body" | jq -r '.vulns[]? // empty' | sed 's/^/  /'
        echo ""
        echo "CPEs:"
        echo "$body" | jq -r '.cpes[]? // empty' | sed 's/^/  /'
      fi
      ;;
    crtsh)
      local body
      body=$(_reverse_crtsh "$target") || return $?
      if [[ "$json_mode" == "1" ]]; then
        printf '%s\n' "$body"
      else
        echo "=== Reverse IP Lookup: $target (crt.sh Certificate Transparency) ==="
        echo ""
        echo "$body" | jq -r '.[].common_name // "-"' | sort -u
      fi
      ;;
    ptr)
      local result
      result=$(_reverse_ptr "$target") || return $?
      if [[ "$json_mode" == "1" ]]; then
        printf '%s\n' "$result" | jq -R -s 'split("\n") | map(select(length > 0))'
      else
        echo "=== Reverse IP Lookup: $target (PTR record) ==="
        if [[ -n "$result" ]]; then
          printf '%s\n' "$result"
        fi
      fi
      ;;
    *)
      echo "ERROR: неизвестный провайдер '$REVERSE_PROVIDER' (см. --reverse-providers)" >&2
      return 2
      ;;
  esac
}
