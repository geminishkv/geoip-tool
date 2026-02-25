#!/usr/bin/env bash
set -euo pipefail

cmd_lookup() {
  local target="${1:-}"
  local body
  body=$(provider_request_with_cache "$target" "$DEFAULT_LANG")

  case "$PROVIDER" in
    ip-api)
      echo "$body" | jq -r '
        if .status != "success" then
          "ERROR: \(.status // "unknown") - \(.message // "no message")"
        else
          "IP:        \(.query // "-")",
          "Хост:      \(.reverse // "-")",
          "Страна:    \(.country // "-") (\(.countryCode // "-"))",
          "Регион:    \(.regionName // "-")",
          "Город:     \(.city // "-")",
          "Оператор:  \(.isp // "-")",
          "Организация: \(.org // "-")",
          "AS:        \(.as // "-")",
          "Координаты:\(.lat // 0), \(.lon // 0)",
          "Зона:      \(.timezone // "-")",
          "Почтовый:  \(.zip // "-")",
          "Мобильный: " +
            (if .mobile == true then "Да"
             elif .mobile == false then "Нет"
             else "Неизвестно" end),
          "Прокси/VPN: " +
            (if .proxy == true then "Да"
             elif .proxy == false then "Нет"
             else "Неизвестно" end),
          "Хостинг:   " +
            (if .hosting == true then "Да"
             elif .hosting == false then "Нет"
             else "Неизвестно" end)
        end'
      ;;
    ipapi-co)
      echo "$body" | jq -r '
        "IP:        \(.ip // "-")",
        "Страна:    \(.country_name // "-") (\(.country // "-"))",
        "Регион:    \(.region // "-")",
        "Город:     \(.city // "-")",
        "Организация: \(.org // "-")",
        "ASN:       \(.asn // "-")",
        "Координаты:\(.latitude // 0), \(.longitude // 0)",
        "Зона:      \(.timezone // "-")",
        "Почтовый:  \(.postal // "-")"
      '
      ;;
    *)
      echo "ERROR: unknown provider '$PROVIDER' (см. --providers)" >&2
      return 2
      ;;
  esac
}

cmd_json() {
  local target="${1:-}"
  provider_request_with_cache "$target" "$DEFAULT_LANG"
}

cmd_file() {
  local file="${1:-}"
  [[ -z "$file" || ! -f "$file" ]] && { echo "Usage: geoip file <file>"; exit 1; }

  while read -r target; do
    [[ -z "$target" ]] && continue
    echo "=============================="
    echo ">> $target"
    cmd_lookup "$target"
    echo
    sleep 1
  done < "$file"
}