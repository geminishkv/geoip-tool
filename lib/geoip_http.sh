#!/usr/bin/env bash
set -euo pipefail

_cmd_http_help() {
  local fg=$'\033[38;5;117m'
  local gray=$'\033[38;5;245m'
  local reset=$'\033[0m'

  local banner_top banner_bottom

  # small poison ASCII (баннер)
  banner_top=$'
                                                                                         
 @@@@@@@  @@@@@@@@  @@@@@@  @@@ @@@@@@@     @@@@@@@  @@@@@@@@  @@@@@@@  @@@@@@  @@@  @@@ 
!@@       @@!      @@!  @@@ @@! @@!  @@@    @@!  @@@ @@!      !@@      @@!  @@@ @@!@!@@@ 
!@! @!@!@ @!!!:!   @!@  !@! !!@ @!@@!@!     @!@!!@!  @!!!:!   !@!      @!@  !@! @!@@!!@! 
:!!   !!: !!:      !!:  !!! !!: !!:         !!: :!!  !!:      :!!      !!:  !!! !!:  !!! 
 :: :: :  : :: ::   : :. :  :    :           :   : : : :: ::   :: :: :  : :. :  ::    :  
                                                                                         '

  printf '%s\n' "$banner_top" \
    | sed "s/^/${fg}/; s/$/${reset}/"

  printf '\n'

  cat <<'EOF'
  geoip http [опции] <IP|host[:port]|http(s)://host[:port][/base]>

Флаги:
  --auto                  Сначала https, если не получилось — http
  --https                 Принудительно https
  --http                  Принудительно http
  --path /путь            Путь запроса (по умолчанию /)
  --methods CSV           Список методов, напр. GET, HEAD, OPTIONS
  --aggressive            Использовать GET, HEAD, OPTIONS, POST, PUT, PATCH, DELETE, TRACE
  --timeout SEC           Общий таймаут (по умолчанию 10)
  --connect-timeout SEC   Таймаут соединения (по умолчанию 5)
  --follow                Следовать редиректам (-L)
  --insecure              Разрешить небезопасный TLS (-k)
  --all-headers           Печатать все заголовки ответа
  -h, --help              Справка

Примеры:
  geoip http example.com
  geoip http --aggressive example.com
  geoip http example.com --https --path /admin --aggressive
  geoip http https://example.com --methods GET,HEAD
EOF

  banner_bottom=$'
                                                                      
 @@@@@@  @@@@@@@  @@@@@@@   @@@@@@ @@@@@@@@  @@@@@@@ @@@@@@@  @@@@@@  
@@!  @@@ @@!  @@@ @@!  @@@ !@@     @@!      !@@        @!!   @@!  @@@ 
@!@!@!@! @!@@!@!  @!@@!@!   !@@!!  @!!!:!   !@!        @!!   @!@!@!@! 
!!:  !!! !!:      !!:          !:! !!:      :!!        !!:   !!:  !!! 
 :   : :  :        :       ::.: :  : :: ::   :: :: :    :     :   : : 
                                                                      
                                                                      
                                                     Sic Parvis Magna'

  printf '%s\n' "$banner_bottom" \
    | sed "s/^/${fg}/; s/$/${reset}/"

  printf '\n%b%s%b\n' "$gray" "2026 Elijah S Shmakov (c) tool v.1.0" "$reset"
}


cmd_http() {
  local mode="auto"
  local path="/"
  local methods="GET,HEAD,OPTIONS"
  local timeout="10"
  local ctimeout="5"
  local follow="0"
  local insecure="0"
  local aggressive="0"
  local all_headers="0"

  local target=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _cmd_http_help
        return 0
        ;;
      --auto) mode="auto"; shift ;;
      --https) mode="https"; shift ;;
      --http) mode="http"; shift ;;
      --path) shift; path="${1:-/}"; shift ;;
      --methods) shift; methods="${1:-GET,HEAD,OPTIONS}"; shift ;;
      --timeout) shift; timeout="${1:-10}"; shift ;;
      --connect-timeout) shift; ctimeout="${1:-5}"; shift ;;
      --follow) follow="1"; shift ;;
      --insecure) insecure="1"; shift ;;
      --aggressive) aggressive="1"; shift ;;
      --all-headers) all_headers="1"; shift ;;
      --)
        shift
        break
        ;;
      --*)
        echo "Неизвестная опция: $1"
        echo
        _cmd_http_help
        return 2
        ;;
      *)
        if [[ -z "$target" ]]; then
          target="$1"
          shift
        else
          echo "Лишний аргумент: $1"
          echo
          _cmd_http_help
          return 2
        fi
        ;;
    esac
  done

  if [[ -z "$target" ]]; then
    _cmd_http_help
    return 2
  fi

  if [[ "$aggressive" == "1" ]]; then
    methods="GET,HEAD,OPTIONS,POST,PUT,PATCH,DELETE,TRACE"
  fi

  [[ "${path:0:1}" != "/" ]] && path="/$path"

  local base_url=""
  if [[ "$target" =~ ^https?:// ]]; then
    base_url="$target"
    mode="fixed"
  fi

  _join_url() {
    local base="$1"
    local p="$2"
    base="${base%/}"
    echo "${base}${p}"
  }

  local url_http="" url_https="" url=""
  if [[ "$mode" == "fixed" ]]; then
    url="$(_join_url "$base_url" "$path")"
  else
    url_http="$(_join_url "http://${target}" "$path")"
    url_https="$(_join_url "https://${target}" "$path")"
  fi

  local writeout
  writeout=$'\n'"curl_http_code=%{http_code} remote_ip=%{remote_ip} local_ip=%{local_ip} time_total=%{time_total} num_redirects=%{num_redirects}"$'\n'

  _probe_one_url() {
    local url="$1"
    local methods_csv="$2"

    echo "[*] Проверка HTTP-методов: $url"
    echo "[*] methods=$methods_csv timeout=${timeout}s connect-timeout=${ctimeout}s follow=$follow insecure=$insecure"
    echo

    IFS=',' read -r -a mlist <<< "$methods_csv"

    for method in "${mlist[@]}"; do
      method="$(echo "$method" | tr -d '[:space:]')"
      [[ -z "$method" ]] && continue

      echo "===== $method ====="

      local tmp_headers rc out
      tmp_headers="$(mktemp)"

      local curl_args=(-sS -o /dev/null -D "$tmp_headers" -w "$writeout" -X "$method" --max-time "$timeout" --connect-timeout "$ctimeout")
      [[ "$follow" == "1" ]] && curl_args+=(-L)
      [[ "$insecure" == "1" ]] && curl_args+=(-k)

      if [[ "$method" == "POST" || "$method" == "PUT" || "$method" == "PATCH" ]]; then
        curl_args+=(--data '')
      fi

      set +e
      out=$(curl "${curl_args[@]}" "$url" 2>&1)
      rc=$?
      set -e

      local h
      h="$(tr -d '\r' < "$tmp_headers")"

      if [[ -n "$h" ]]; then
        echo "$h" | head -n 1

        if [[ "$all_headers" == "1" ]]; then
          echo "$h" | sed '1d'
        else
          echo "$h" | awk 'BEGIN{IGNORECASE=1} /^server:|^allow:|^location:|^content-type:|^content-length:/ {print}'
        fi

        local allow
        allow="$(echo "$h" | awk 'BEGIN{IGNORECASE=1} /^allow:/ {sub(/^allow:[[:space:]]*/,""); print; exit}')"
        if [[ -n "$allow" ]]; then
          echo "Allow(разобрано): $allow"
        fi
      fi

      if [[ $rc -ne 0 ]]; then
        echo "Ошибка curl (exit code $rc)"
        echo "curl stderr: $out"
      else
        echo "$out"
      fi

      rm -f "$tmp_headers"
      echo
    done
  }

  case "$mode" in
    fixed)
      _probe_one_url "$url" "$methods"
      ;;
    http)
      _probe_one_url "$url_http" "$methods"
      ;;
    https)
      _probe_one_url "$url_https" "$methods"
      ;;
    auto)
      local rc
      set +e
      if [[ "$insecure" == "1" ]]; then
        curl -sS -o /dev/null -I --max-time "$timeout" --connect-timeout "$ctimeout" -k "$url_https" >/dev/null 2>&1
      else
        curl -sS -o /dev/null -I --max-time "$timeout" --connect-timeout "$ctimeout" "$url_https" >/dev/null 2>&1
      fi
      rc=$?
      set -e

      if [[ $rc -eq 0 ]]; then
        _probe_one_url "$url_https" "$methods"
      else
        _probe_one_url "$url_http" "$methods"
      fi
      ;;
    *)
      echo "Внутренняя ошибка: неизвестный режим '$mode'"
      return 2
      ;;
  esac
}
