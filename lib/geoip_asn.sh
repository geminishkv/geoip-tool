#!/usr/bin/env bash
set -euo pipefail

_cmd_asn_help() {
  _banner
  printf "  ${C_DIM}ASN lookup — информация об автономной системе через RIPE Stat${C_RESET}\n"

  _h "Использование"
  _exm "geoip asn <IP|ASN>"

  _h "Опции"
  _opt "--json" "Вывод в формате JSON"
  _opt "-h, --help" "Справка"

  _h "Примеры"
  _exm "geoip asn 8.8.8.8"
  _exm "geoip asn AS15169"
  _exm "geoip asn 15169"
  _exm "geoip asn --json 1.1.1.1"
  echo ""
}

# Получить ASN и prefix по IP через RIPE Stat
_ripe_network_info() {
  local ip="$1"
  curl -sS --max-time 15 "https://stat.ripe.net/data/network-info/data.json?resource=${ip}"
}

# Получить детали AS по номеру через RIPE Stat
_ripe_as_overview() {
  local asn="$1"
  curl -sS --max-time 15 "https://stat.ripe.net/data/as-overview/data.json?resource=AS${asn}"
}

# Получить список префиксов AS через RIPE Stat
_ripe_announced_prefixes() {
  local asn="$1"
  curl -sS --max-time 15 "https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS${asn}"
}

_asn_pretty() {
  local asn="$1"
  local overview="$2"
  local prefixes="$3"

  local holder type
  holder=$(echo "$overview" | jq -r '.data.holder // "-"')
  type=$(echo "$overview" | jq -r '.data.type // "-"')

  printf '%b\n' "${C_CYAN}ASN:${C_RESET}         AS${asn}"
  printf '%b\n' "${C_CYAN}Holder:${C_RESET}      ${holder}"
  printf '%b\n' "${C_CYAN}Тип:${C_RESET}         ${type}"

  # Префиксы
  local count
  count=$(echo "$prefixes" | jq -r '.data.prefixes | length // 0')
  printf '%b\n' "${C_CYAN}Префиксов:${C_RESET}   ${count}"

  if (( count > 0 )); then
    echo ""
    printf '%b\n' "${C_BOLD}Анонсируемые префиксы:${C_RESET}"
    echo "$prefixes" | jq -r '.data.prefixes[:20][] | "  \(.prefix)  \(.timelines[0].starttime // "-")"' 2>/dev/null || true
    if (( count > 20 )); then
      printf '%b\n' "  ${C_DIM}... и ещё $((count - 20)) префиксов${C_RESET}"
    fi
  fi
}

cmd_asn() {
  local target=""
  local json_mode=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _cmd_asn_help
        return 0
        ;;
      --json)  json_mode=1; shift ;;
      --)      shift; break ;;
      --*)
        echo "Неизвестная опция: $1" >&2
        _cmd_asn_help
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
    >&2 echo "ERROR: необходим IP-адрес или номер ASN"
    _cmd_asn_help
    return 2
  fi

  local asn=""
  local prefix="-"
  local network_info=""

  # Определяем: IP или ASN
  # Убираем префикс AS/as если есть
  local clean="${target#AS}"
  clean="${clean#as}"

  if [[ "$clean" =~ ^[0-9]+$ ]]; then
    # Это номер ASN
    asn="$clean"
  else
    # Это IP — сначала получим ASN
    network_info=$(_ripe_network_info "$target")

    local status
    status=$(echo "$network_info" | jq -r '.status // "error"')
    if [[ "$status" != "ok" ]]; then
      printf '%b\n' "${C_RED}ERROR: RIPE Stat вернул статус: ${status}${C_RESET}" >&2
      return 1
    fi

    asn=$(echo "$network_info" | jq -r '.data.asns[0] // empty')
    prefix=$(echo "$network_info" | jq -r '.data.prefix // "-"')

    if [[ -z "$asn" ]]; then
      printf '%b\n' "${C_RED}ERROR: не удалось определить ASN для ${target}${C_RESET}" >&2
      return 1
    fi
  fi

  # Получаем детали AS и префиксы
  local overview prefixes
  overview=$(_ripe_as_overview "$asn")
  prefixes=$(_ripe_announced_prefixes "$asn")

  if [[ "$json_mode" == "1" ]]; then
    local result='{}'
    result=$(echo "$result" | jq --arg t "$target" '. + {query: $t}')
    result=$(echo "$result" | jq --arg a "$asn" '. + {asn: ("AS" + $a)}')
    [[ "$prefix" != "-" ]] && result=$(echo "$result" | jq --arg p "$prefix" '. + {prefix: $p}')

    if echo "$overview" | jq -e '.data' >/dev/null 2>&1; then
      result=$(echo "$result" | jq --argjson v "$(echo "$overview" | jq '.data')" '. + {overview: $v}')
    fi
    if echo "$prefixes" | jq -e '.data.prefixes' >/dev/null 2>&1; then
      result=$(echo "$result" | jq --argjson v "$(echo "$prefixes" | jq '[.data.prefixes[] | {prefix: .prefix}]')" '. + {prefixes: $v}')
    fi

    echo "$result" | jq '.'
    return 0
  fi

  # Pretty output
  if [[ "$prefix" != "-" ]]; then
    printf '%b\n' "${C_CYAN}IP:${C_RESET}          ${target}"
    printf '%b\n' "${C_CYAN}Префикс:${C_RESET}     ${prefix}"
  fi

  _asn_pretty "$asn" "$overview" "$prefixes"
}
