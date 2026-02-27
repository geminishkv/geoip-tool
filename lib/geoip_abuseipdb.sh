#!/usr/bin/env bash
set -euo pipefail

_cmd_abuse_help() {
  cat <<'EOF'
Использование:
  geoip abuse [опции] <IP>

Проверка IP через AbuseIPDB (репутация, жалобы, категории).

Опции:
  --days N          Период проверки в днях (по умолчанию 90)
  --verbose         Показать последние репорты
  --json            Вывод в JSON формате
  -h, --help        Справка

Требуется API-ключ:
  geoip config set ABUSEIPDB_API_KEY <ваш_ключ>
  Получить бесплатно: https://www.abuseipdb.com/account/api

Примеры:
  geoip abuse 8.8.8.8
  geoip abuse --verbose 185.220.101.1
  geoip abuse --days 30 --json 8.8.8.8
EOF
}

cmd_abuse() {
  local target=""
  local days=90
  local json_mode=0
  local verbose=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _cmd_abuse_help
        return 0
        ;;
      --days)   shift; days="${1:-90}"; shift ;;
      --json)   json_mode=1; shift ;;
      --verbose) verbose=1; shift ;;
      --)       shift; break ;;
      --*)
        echo "Неизвестная опция: $1" >&2
        _cmd_abuse_help
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
    >&2 echo "ERROR: необходим IP-адрес"
    _cmd_abuse_help
    return 2
  fi

  local api_key="${ABUSEIPDB_API_KEY:-}"
  if [[ -z "$api_key" ]]; then
    >&2 echo "ERROR: ABUSEIPDB_API_KEY не задан"
    >&2 echo "Установите: geoip config set ABUSEIPDB_API_KEY <ключ>"
    >&2 echo "Получить: https://www.abuseipdb.com/account/api"
    return 2
  fi

  local url="https://api.abuseipdb.com/api/v2/check?ipAddress=${target}&maxAgeInDays=${days}&verbose"
  local body
  body=$(curl -sS --max-time 15 -H "Key: ${api_key}" -H "Accept: application/json" "$url")

  # Проверка ошибок API
  local errors
  errors=$(echo "$body" | jq -r '.errors // empty')
  if [[ -n "$errors" && "$errors" != "null" ]]; then
    local detail
    detail=$(echo "$body" | jq -r '.errors[0].detail // "unknown error"')
    >&2 echo "ERROR: AbuseIPDB: $detail"
    return 1
  fi

  if [[ "$json_mode" == "1" ]]; then
    printf '%s\n' "$body"
    return 0
  fi

  local data
  data=$(echo "$body" | jq '.data')

  local ip score total_reports country isp domain usage_type last_report is_public
  eval "$(echo "$data" | jq -r '
    @sh "ip=\(.ipAddress // "-")",
    @sh "score=\(.abuseConfidenceScore // 0)",
    @sh "total_reports=\(.totalReports // 0)",
    @sh "country=\(.countryCode // "-")",
    @sh "isp=\(.isp // "-")",
    @sh "domain=\(.domain // "-")",
    @sh "usage_type=\(.usageType // "-")",
    @sh "last_report=\(.lastReportedAt // "-")",
    @sh "is_public=\(.isPublic // false)"
  ')"

  # Цвет score
  local score_color="$C_GREEN"
  if (( score > 75 )); then
    score_color="$C_RED"
  elif (( score > 25 )); then
    score_color="$C_YELLOW"
  fi

  local verdict="${C_GREEN}Чисто${C_RESET}"
  if (( score > 75 )); then
    verdict="${C_RED}Опасно${C_RESET}"
  elif (( score > 25 )); then
    verdict="${C_YELLOW}Подозрительно${C_RESET}"
  elif (( total_reports > 0 )); then
    verdict="${C_YELLOW}Есть жалобы${C_RESET}"
  fi

  printf '%b\n' "${C_BOLD}=== AbuseIPDB: $target ===${C_RESET}"
  echo ""
  printf '%b\n' "${C_CYAN}IP:${C_RESET}            $ip"
  printf '%b\n' "${C_CYAN}Вердикт:${C_RESET}       $verdict"
  printf '%b\n' "${C_CYAN}Score:${C_RESET}          ${score_color}${score}/100${C_RESET}"
  printf '%b\n' "${C_CYAN}Жалоб:${C_RESET}         $total_reports"
  printf '%b\n' "${C_CYAN}Страна:${C_RESET}        $country"
  printf '%b\n' "${C_CYAN}Провайдер:${C_RESET}     $isp"
  printf '%b\n' "${C_CYAN}Домен:${C_RESET}         $domain"
  printf '%b\n' "${C_CYAN}Тип:${C_RESET}           $usage_type"
  printf '%b\n' "${C_CYAN}Публичный:${C_RESET}     $is_public"
  printf '%b\n' "${C_CYAN}Последняя:${C_RESET}     $last_report"
  printf '%b\n' "${C_CYAN}Период:${C_RESET}        ${days} дней"

  if [[ "$verbose" == "1" ]]; then
    local report_count
    report_count=$(echo "$data" | jq '.reports | length')

    if (( report_count > 0 )); then
      echo ""
      printf '%b\n' "${C_BOLD}--- Последние репорты (до 5) ---${C_RESET}"

      echo "$data" | jq -r '.reports[:5][] |
        "\(.reportedAt) | cat: \(.categories | join(",")) | \(.comment // "-")"
      ' | while IFS= read -r line; do
        printf '%b\n' "  ${C_DIM}${line}${C_RESET}"
      done
    else
      echo ""
      printf '%b\n' "${C_DIM}Репортов нет${C_RESET}"
    fi
  fi
}
