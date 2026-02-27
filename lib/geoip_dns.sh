#!/usr/bin/env bash
set -euo pipefail

_cmd_dns_help() {
  cat <<'EOF'
Использование:
  geoip dns [опции] <домен>

DNS-разведка — запрос DNS-записей для домена.

Опции:
  --type TYPE        Тип записи: A, AAAA, MX, NS, TXT, SOA, CNAME
                     Без --type запрашиваются все основные типы
  --nameserver NS    DNS-сервер для запросов (по умолчанию системный)
  --short            Только значения, без заголовков
  --json             JSON вывод
  -h, --help         Справка

Примеры:
  geoip dns example.com
  geoip dns --type MX google.com
  geoip dns --type TXT example.com
  geoip dns --nameserver 8.8.8.8 example.com
  geoip dns --json example.com
EOF
}

_dns_query_dig() {
  local domain="$1" rtype="$2" ns="${3:-}"
  local args=("$domain" "$rtype" "+short" "+time=5" "+tries=2")
  if [[ -n "$ns" ]]; then
    args=("@${ns}" "${args[@]}")
  fi
  dig "${args[@]}" 2>/dev/null | grep -v '^$' || true
}

_dns_query_nslookup() {
  local domain="$1" rtype="$2" ns="${3:-}"

  local args=()
  if [[ -n "$ns" ]]; then
    args+=("$domain" "$ns")
  else
    args+=("$domain")
  fi

  case "$rtype" in
    A|AAAA)
      nslookup -type="$rtype" "${args[@]}" 2>/dev/null \
        | awk '/^(Address|Addresses)/ && !/^Addresses:/ {sub(/^[^:]+:[[:space:]]*/,""); if ($0 !~ /#/) print}' \
        | tail -n +2 || true
      ;;
    MX)
      nslookup -type=MX "${args[@]}" 2>/dev/null \
        | awk '/mail exchanger/ {sub(/.*mail exchanger = /,""); print}' || true
      ;;
    NS)
      nslookup -type=NS "${args[@]}" 2>/dev/null \
        | awk '/nameserver/ {sub(/.*nameserver = /,""); print}' || true
      ;;
    TXT)
      nslookup -type=TXT "${args[@]}" 2>/dev/null \
        | awk '/text =/ {
            val = $0
            sub(/.*text = */,"",val)
            if (val != "" && val != "\"\"") print val
          }
          /^[[:space:]]+"/ { gsub(/^[[:space:]]+/,""); print }
        ' || true
      ;;
    SOA)
      nslookup -type=SOA "${args[@]}" 2>/dev/null \
        | awk '/origin|mail addr|serial|refresh|retry|expire|minimum/ {print}' || true
      ;;
    CNAME)
      nslookup -type=CNAME "${args[@]}" 2>/dev/null \
        | awk '/canonical name/ {sub(/.*canonical name = /,""); print}' || true
      ;;
    *)
      nslookup -type="$rtype" "${args[@]}" 2>/dev/null || true
      ;;
  esac
}

_dns_query() {
  local domain="$1" rtype="$2" ns="${3:-}"
  if command -v dig &>/dev/null; then
    _dns_query_dig "$domain" "$rtype" "$ns"
  elif command -v nslookup &>/dev/null; then
    _dns_query_nslookup "$domain" "$rtype" "$ns"
  else
    >&2 echo "ERROR: ни dig, ни nslookup не найдены в PATH"
    return 1
  fi
}

cmd_dns() {
  local target=""
  local record_type=""
  local nameserver=""
  local json_mode=0
  local short_mode=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _cmd_dns_help
        return 0
        ;;
      --type)       shift; record_type="${1:-}"; shift ;;
      --type=*)     record_type="${1#*=}"; shift ;;
      --nameserver) shift; nameserver="${1:-}"; shift ;;
      --nameserver=*) nameserver="${1#*=}"; shift ;;
      --json)       json_mode=1; shift ;;
      --short)      short_mode=1; shift ;;
      --)           shift; break ;;
      --*)
        echo "Неизвестная опция: $1" >&2
        _cmd_dns_help
        return 2
        ;;
      *)
        if [[ -z "$target" ]]; then
          target="$1"; shift
        else
          echo "Лишний аргумент: $1" >&2
          return 2
        fi
        ;;
    esac
  done

  if [[ -z "$target" ]]; then
    >&2 echo "ERROR: необходим домен"
    _cmd_dns_help
    return 2
  fi

  local types
  if [[ -n "$record_type" ]]; then
    record_type=$(echo "$record_type" | tr '[:lower:]' '[:upper:]')
    types=("$record_type")
  else
    types=(A AAAA MX NS TXT SOA CNAME)
  fi

  if [[ "$json_mode" == "1" ]]; then
    # JSON: собираем объект {"A": [...], "MX": [...], ...}
    local json_result="{}"
    for rtype in "${types[@]}"; do
      local result
      result=$(_dns_query "$target" "$rtype" "$nameserver")
      if [[ -n "$result" ]]; then
        local arr
        arr=$(printf '%s\n' "$result" | jq -R -s 'split("\n") | map(select(length > 0))')
        json_result=$(echo "$json_result" | jq --arg k "$rtype" --argjson v "$arr" '. + {($k): $v}')
      else
        json_result=$(echo "$json_result" | jq --arg k "$rtype" '. + {($k): []}')
      fi
    done
    echo "$json_result" | jq '.'
    return 0
  fi

  if [[ "$short_mode" == "0" ]]; then
    printf '%b\n' "${C_BOLD}=== DNS: $target ===${C_RESET}"
    [[ -n "$nameserver" ]] && printf '%b\n' "${C_DIM}Сервер: $nameserver${C_RESET}"
    echo ""
  fi

  for rtype in "${types[@]}"; do
    local result
    result=$(_dns_query "$target" "$rtype" "$nameserver")

    if [[ -n "$result" ]]; then
      if [[ "$short_mode" == "1" ]]; then
        printf '%s\n' "$result"
      else
        printf '%b\n' "${C_CYAN}${rtype}:${C_RESET}"
        printf '%s\n' "$result" | sed 's/^/  /'
        echo ""
      fi
    elif [[ "$short_mode" == "0" && -n "$record_type" ]]; then
      printf '%b\n' "${C_CYAN}${rtype}:${C_RESET} ${C_DIM}(нет записей)${C_RESET}"
      echo ""
    fi
  done
}
