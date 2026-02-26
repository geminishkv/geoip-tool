#!/usr/bin/env bash
set -euo pipefail

_color_bool() {
  local val="$1"
  case "$val" in
    true)  printf '%b' "${C_GREEN}Да${C_RESET}" ;;
    false) printf '%b' "${C_DIM}Нет${C_RESET}" ;;
    *)     printf '%b' "${C_YELLOW}Неизвестно${C_RESET}" ;;
  esac
}

_lookup_pretty_ip_api() {
  local body="$1"
  local status
  status=$(echo "$body" | jq -r '.status // "unknown"')

  if [[ "$status" != "success" ]]; then
    local msg
    msg=$(echo "$body" | jq -r '.message // "no message"')
    printf '%b\n' "${C_RED}ERROR: ${status} - ${msg}${C_RESET}"
    return 1
  fi

  local query reverse country cc region city isp org as lat lon tz zip mobile proxy hosting
  eval "$(echo "$body" | jq -r '
    @sh "query=\(.query // "-")",
    @sh "reverse=\(.reverse // "-")",
    @sh "country=\(.country // "-")",
    @sh "cc=\(.countryCode // "-")",
    @sh "region=\(.regionName // "-")",
    @sh "city=\(.city // "-")",
    @sh "isp=\(.isp // "-")",
    @sh "org=\(.org // "-")",
    @sh "as_field=\(.as // "-")",
    @sh "lat=\(.lat // 0)",
    @sh "lon=\(.lon // 0)",
    @sh "tz=\(.timezone // "-")",
    @sh "zip=\(.zip // "-")",
    @sh "mobile=\(.mobile // "null")",
    @sh "proxy=\(.proxy // "null")",
    @sh "hosting=\(.hosting // "null")"
  ')"

  printf '%b\n' "${C_CYAN}IP:${C_RESET}          $query"
  printf '%b\n' "${C_CYAN}Хост:${C_RESET}        $reverse"
  printf '%b\n' "${C_CYAN}Страна:${C_RESET}      $country ($cc)"
  printf '%b\n' "${C_CYAN}Регион:${C_RESET}      $region"
  printf '%b\n' "${C_CYAN}Город:${C_RESET}       $city"
  printf '%b\n' "${C_CYAN}Оператор:${C_RESET}    $isp"
  printf '%b\n' "${C_CYAN}Организация:${C_RESET} $org"
  printf '%b\n' "${C_CYAN}AS:${C_RESET}          $as_field"
  printf '%b\n' "${C_CYAN}Координаты:${C_RESET}  $lat, $lon"
  printf '%b\n' "${C_CYAN}Зона:${C_RESET}        $tz"
  printf '%b\n' "${C_CYAN}Почтовый:${C_RESET}    $zip"
  printf '%b' "${C_CYAN}Мобильный:${C_RESET}   "; _color_bool "$mobile"; echo
  printf '%b' "${C_CYAN}Прокси/VPN:${C_RESET}  "; _color_bool "$proxy"; echo
  printf '%b' "${C_CYAN}Хостинг:${C_RESET}     "; _color_bool "$hosting"; echo
}

_lookup_pretty_ipapi_co() {
  local body="$1"

  local ip country_name cc region city org asn lat lon tz postal
  eval "$(echo "$body" | jq -r '
    @sh "ip=\(.ip // "-")",
    @sh "country_name=\(.country_name // "-")",
    @sh "cc=\(.country // "-")",
    @sh "region=\(.region // "-")",
    @sh "city=\(.city // "-")",
    @sh "org=\(.org // "-")",
    @sh "asn=\(.asn // "-")",
    @sh "lat=\(.latitude // 0)",
    @sh "lon=\(.longitude // 0)",
    @sh "tz=\(.timezone // "-")",
    @sh "postal=\(.postal // "-")"
  ')"

  printf '%b\n' "${C_CYAN}IP:${C_RESET}          $ip"
  printf '%b\n' "${C_CYAN}Страна:${C_RESET}      $country_name ($cc)"
  printf '%b\n' "${C_CYAN}Регион:${C_RESET}      $region"
  printf '%b\n' "${C_CYAN}Город:${C_RESET}       $city"
  printf '%b\n' "${C_CYAN}Организация:${C_RESET} $org"
  printf '%b\n' "${C_CYAN}ASN:${C_RESET}         $asn"
  printf '%b\n' "${C_CYAN}Координаты:${C_RESET}  $lat, $lon"
  printf '%b\n' "${C_CYAN}Зона:${C_RESET}        $tz"
  printf '%b\n' "${C_CYAN}Почтовый:${C_RESET}    $postal"
}

cmd_lookup() {
  local target="${1:-}"
  local body
  body=$(provider_request_with_cache "$target" "$DEFAULT_LANG")

  case "$OUTPUT_FORMAT" in
    json)
      printf '%s\n' "$body"
      return 0
      ;;
    jsonl)
      echo "$body" | jq -c '.'
      return 0
      ;;
    csv|tsv)
      local sep=","
      [[ "$OUTPUT_FORMAT" == "tsv" ]] && sep=$'\t'
      case "$PROVIDER" in
        ip-api)
          echo "$body" | jq -r --arg s "$sep" \
            '[.query,.reverse,.country,.countryCode,.regionName,.city,.isp,.org,.as,(.lat|tostring),(.lon|tostring),.timezone,.zip] | join($s)'
          ;;
        ipapi-co)
          echo "$body" | jq -r --arg s "$sep" \
            '[.ip,"-",.country_name,.country,.region,.city,"-",.org,.asn,(.latitude|tostring),(.longitude|tostring),.timezone,.postal] | join($s)'
          ;;
      esac
      return 0
      ;;
  esac

  case "$PROVIDER" in
    ip-api)    _lookup_pretty_ip_api "$body" ;;
    ipapi-co)  _lookup_pretty_ipapi_co "$body" ;;
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

  # CSV/TSV: напечатать заголовок один раз
  if [[ "$OUTPUT_FORMAT" == "csv" || "$OUTPUT_FORMAT" == "tsv" ]]; then
    local sep=","
    [[ "$OUTPUT_FORMAT" == "tsv" ]] && sep=$'\t'
    local hdr
    hdr=$(printf '%s' "ip${sep}host${sep}country${sep}country_code${sep}region${sep}city${sep}isp${sep}org${sep}as${sep}lat${sep}lon${sep}timezone${sep}zip")
    echo "$hdr"
  fi

  _file_loop() {
    while read -r target; do
      [[ -z "$target" || "$target" == \#* ]] && continue
      if [[ "$OUTPUT_FORMAT" == "pretty" ]]; then
        echo "=============================="
        printf '%b\n' "${C_BOLD}>> $target${C_RESET}"
      fi
      cmd_lookup "$target"
      [[ "$OUTPUT_FORMAT" == "pretty" ]] && echo
      sleep 1
    done
  }

  if [[ "$file" == "-" ]] || [[ -z "$file" && ! -t 0 ]]; then
    _file_loop
  else
    [[ -z "$file" || ! -f "$file" ]] && { echo "Usage: geoip file <file|->" >&2; return 1; }
    _file_loop < "$file"
  fi
}