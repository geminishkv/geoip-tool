#!/usr/bin/env bash
set -euo pipefail

_cmd_whois_help() {
  _banner
  printf "  ${C_DIM}WHOIS lookup — информация о владельце IP-адреса или домена${C_RESET}\n"

  _h "Использование"
  _exm "geoip whois [опции] <IP|домен>"

  _h "Опции"
  _opt "--raw" "Полный raw-вывод whois"
  _opt "--json" "JSON вывод (ARIN REST API, только для IP)"
  _opt "-h, --help" "Справка"

  _h "Методы"
  _opt "1. whois (CLI)" "Системная команда (если установлена)"
  _opt "2. ARIN REST API" "Fallback для IP (без whois)"

  _h "Примеры"
  _exm "geoip whois 8.8.8.8"
  _exm "geoip whois --raw 8.8.8.8"
  _exm "geoip whois --json 8.8.8.8"
  _exm "geoip whois example.com"
  echo ""
}

_whois_cli() {
  local target="$1"
  whois "$target" 2>/dev/null
}

_whois_parse_fields() {
  local raw="$1"
  # Извлекаем ключевые поля из raw whois (RIPE/ARIN/APNIC форматы)
  local netname org country range descr created updated

  netname=$(echo "$raw" | awk -F: '/^[Nn]et[Nn]ame|^netname/ {gsub(/^[[:space:]]+/,"",$2); print $2; exit}')
  org=$(echo "$raw" | awk -F: '/^[Oo]rg[Nn]ame|^org-name|^[Oo]rganization/ {gsub(/^[[:space:]]+/,"",$2); print $2; exit}')
  country=$(echo "$raw" | awk -F: '/^[Cc]ountry/ {gsub(/^[[:space:]]+/,"",$2); print toupper($2); exit}')
  range=$(echo "$raw" | awk '/^[Nn]et[Rr]ange|^inetnum|^CIDR/ {sub(/^[^:]+:[[:space:]]*/,""); print; exit}')
  descr=$(echo "$raw" | awk -F: '/^descr/ {gsub(/^[[:space:]]+/,"",$2); print $2; exit}')
  created=$(echo "$raw" | awk -F: '/^[Rr]eg[Dd]ate|^created/ {gsub(/^[[:space:]]+/,"",$2); print $2; exit}')
  updated=$(echo "$raw" | awk -F: '/^[Uu]pdated|^last-modified/ {gsub(/^[[:space:]]+/,"",$2); print $2; exit}')

  # Domain-specific fields
  local registrar nameservers expires
  registrar=$(echo "$raw" | awk '/^[[:space:]]*[Rr]egistrar:/ {sub(/^[^:]+:[[:space:]]*/,""); print; exit}')
  nameservers=$(echo "$raw" | awk '/^[[:space:]]*[Nn]ame [Ss]erver:/ {sub(/^[^:]+:[[:space:]]*/,""); print}' | head -4 | tr '\n' ', ' | sed 's/,$//')
  expires=$(echo "$raw" | awk '/[Ee]xpir.*[Dd]ate|[Ee]xpiry/ {sub(/^[^:]+:[[:space:]]*/,""); print; exit}')

  printf '%b\n' "${C_CYAN}Имя сети:${C_RESET}      ${netname:--}"
  printf '%b\n' "${C_CYAN}Диапазон:${C_RESET}      ${range:--}"
  printf '%b\n' "${C_CYAN}Описание:${C_RESET}      ${descr:--}"
  printf '%b\n' "${C_CYAN}Организация:${C_RESET}   ${org:--}"
  printf '%b\n' "${C_CYAN}Страна:${C_RESET}        ${country:--}"
  printf '%b\n' "${C_CYAN}Создано:${C_RESET}       ${created:--}"
  printf '%b\n' "${C_CYAN}Обновлено:${C_RESET}     ${updated:--}"

  if [[ -n "$registrar" ]]; then
    printf '%b\n' "${C_CYAN}Регистратор:${C_RESET}   ${registrar}"
  fi
  if [[ -n "$nameservers" ]]; then
    printf '%b\n' "${C_CYAN}NS:${C_RESET}            ${nameservers}"
  fi
  if [[ -n "$expires" ]]; then
    printf '%b\n' "${C_CYAN}Истекает:${C_RESET}      ${expires}"
  fi
}

_whois_web() {
  local ip="$1"
  local url="https://whois.arin.net/rest/ip/${ip}.json"
  curl -sS --max-time 15 -H "Accept: application/json" "$url"
}

_whois_web_pretty() {
  local body="$1"

  local netname org_name start_addr end_addr cidr created updated
  eval "$(echo "$body" | jq -r '
    .net as $n |
    @sh "netname=\($n.name."$" // "-")",
    @sh "org_name=\($n.orgRef."@name" // "-")",
    @sh "start_addr=\($n.startAddress."$" // "-")",
    @sh "end_addr=\($n.endAddress."$" // "-")",
    @sh "created=\($n.registrationDate."$" // "-")",
    @sh "updated=\($n.updateDate."$" // "-")"
  ')"

  printf '%b\n' "${C_CYAN}Имя сети:${C_RESET}      $netname"
  printf '%b\n' "${C_CYAN}Диапазон:${C_RESET}      $start_addr - $end_addr"
  printf '%b\n' "${C_CYAN}Организация:${C_RESET}   $org_name"
  printf '%b\n' "${C_CYAN}Создано:${C_RESET}       $created"
  printf '%b\n' "${C_CYAN}Обновлено:${C_RESET}     $updated"
}

cmd_whois() {
  local target=""
  local json_mode=0
  local raw_mode=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _cmd_whois_help
        return 0
        ;;
      --json) json_mode=1; shift ;;
      --raw)  raw_mode=1; shift ;;
      --)     shift; break ;;
      --*)
        echo "Неизвестная опция: $1" >&2
        _cmd_whois_help
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
    >&2 echo "ERROR: необходим IP-адрес или домен"
    _cmd_whois_help
    return 2
  fi

  printf '%b\n' "${C_BOLD}=== WHOIS: $target ===${C_RESET}"
  echo ""

  # JSON mode — всегда через ARIN API
  if [[ "$json_mode" == "1" ]]; then
    local body
    body=$(_whois_web "$target")
    printf '%s\n' "$body"
    return 0
  fi

  # Если есть системный whois
  if command -v whois &>/dev/null; then
    local raw
    raw=$(_whois_cli "$target")

    if [[ -z "$raw" ]]; then
      >&2 echo "ERROR: whois не вернул данных для $target"
      return 1
    fi

    if [[ "$raw_mode" == "1" ]]; then
      printf '%s\n' "$raw"
    else
      _whois_parse_fields "$raw"
    fi
    return 0
  fi

  # Fallback: ARIN REST API (только для IP)
  if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    >&2 echo "[whois] Команда whois не найдена, используем ARIN REST API"
    local body
    body=$(_whois_web "$target")

    if ! echo "$body" | jq -e '.net' >/dev/null 2>&1; then
      >&2 echo "ERROR: ARIN API — невалидный ответ"
      return 1
    fi

    _whois_web_pretty "$body"
  else
    >&2 echo "ERROR: команда whois не найдена в PATH"
    >&2 echo "Для доменов требуется whois. Установка:"
    >&2 echo "  Debian/Ubuntu: sudo apt install whois"
    >&2 echo "  macOS:         brew install whois"
    >&2 echo "  Windows:       используйте IP-адрес (ARIN API доступен)"
    return 1
  fi
}
