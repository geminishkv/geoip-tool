#!/usr/bin/env bash
set -euo pipefail

cmd_lookup() {
  local target="${1:-}"
  local body
  body=$(ipapi_request_with_cache "$target" "$DEFAULT_LANG")

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
}

cmd_json() {
  local target="${1:-}"
  local fields="status,message,query,country,regionName,city,isp,org,as,lat,lon,timezone,proxy,hosting"
  local url

  if [[ -z "$target" ]]; then
    url="${API_BASE}/?lang=${DEFAULT_LANG}&fields=${fields}"
  else
    url="${API_BASE}/${target}?lang=${DEFAULT_LANG}&fields=${fields}"
  fi

  curl -s "$url"
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