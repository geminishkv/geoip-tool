#!/usr/bin/env bash
set -euo pipefail

_cmd_http_help() {
  _banner
  printf "  ${C_DIM}Пробинг HTTP-методов на целевом хосте${C_RESET}\n"

  _h "Использование"
  _exm "geoip http [опции] <IP|host[:port]|http(s)://host[:port][/base]>"

  _h "Опции"
  _opt "--auto" "Сначала https, если не получилось — http"
  _opt "--https" "Принудительно https"
  _opt "--http" "Принудительно http"
  _opt "--path /путь" "Путь запроса (по умолчанию /)"
  _opt "--methods CSV" "Список методов, напр. GET,HEAD,OPTIONS"
  _opt "--aggressive" "GET, HEAD, OPTIONS, POST, PUT, PATCH, DELETE, TRACE"
  _opt "--ports CSV" "Порты для проверки, напр. 80,443,8080,8443"
  _opt "--timeout SEC" "Общий таймаут (по умолчанию 10)"
  _opt "--connect-timeout SEC" "Таймаут соединения (по умолчанию 5)"
  _opt "--follow" "Следовать редиректам (-L)"
  _opt "--insecure" "Разрешить небезопасный TLS (-k)"
  _opt "--all-headers" "Печатать все заголовки ответа"
  _opt "-h, --help" "Справка"

  _h "Примеры"
  _exm "geoip http example.com"
  _exm "geoip http --aggressive example.com"
  _exm "geoip http --https --path /admin --aggressive example.com"
  _exm "geoip http --ports 80,443,8080 example.com"
  echo ""
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
  local custom_ports=""

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
      --ports) shift; custom_ports="${1:-}"; shift ;;
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
  writeout=$'\n'": curl_http_code=%{http_code} remote_ip=%{remote_ip} local_ip=%{local_ip} time_total=%{time_total} num_redirects=%{num_redirects}"$'\n'

  _probe_one_url() {
    local url="$1"
    local methods_csv="$2"

    printf '%b\n' "${C_BOLD}[*] Проверка HTTP-методов: $url${C_RESET}"
    printf '%b\n' "${C_DIM}[*] methods=$methods_csv timeout=${timeout}s connect-timeout=${ctimeout}s follow=$follow insecure=$insecure${C_RESET}"
    echo

    IFS=',' read -r -a mlist <<< "$methods_csv"

    for method in "${mlist[@]}"; do
      method="$(echo "$method" | tr -d '[:space:]')"
      [[ -z "$method" ]] && continue

      printf '%b\n' "${C_BOLD}===== $method =====${C_RESET}"

      local tmp_headers rc out
      tmp_headers="$(mktemp)"

      local curl_args=(-sS -D "$tmp_headers" -w "$writeout" --max-time "$timeout" --connect-timeout "$ctimeout")
      if [[ "$method" == "HEAD" ]]; then
        curl_args+=(-I -o /dev/null)
      else
        curl_args+=(-o /dev/null -X "$method")
      fi
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
        local status_line
        status_line=$(echo "$h" | head -n 1)
        local code
        code=$(echo "$status_line" | awk '{print $2}')
        if [[ "$code" =~ ^2 ]]; then
          printf '%b\n' "${C_GREEN}${status_line}${C_RESET}"
        elif [[ "$code" =~ ^4 ]]; then
          printf '%b\n' "${C_YELLOW}${status_line}${C_RESET}"
        elif [[ "$code" =~ ^5 ]]; then
          printf '%b\n' "${C_RED}${status_line}${C_RESET}"
        else
          echo "$status_line"
        fi

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
        printf '%b\n' "${C_RED}Ошибка curl (exit code $rc)${C_RESET}"
        printf '%b\n' "${C_RED}curl stderr: $out${C_RESET}"
      else
        echo "$out"
      fi

      rm -f "$tmp_headers"
      echo
    done
  }

  _build_url_with_port() {
    local scheme="$1" host="$2" port="$3" p="$4"
    if [[ "$scheme" == "http" && "$port" == "80" ]] || \
       [[ "$scheme" == "https" && "$port" == "443" ]]; then
      echo "${scheme}://${host}${p}"
    else
      echo "${scheme}://${host}:${port}${p}"
    fi
  }

  _probe_auto() {
    local url_h="$1" url_hs="$2"
    local rc
    set +e
    if [[ "$insecure" == "1" ]]; then
      curl -sS -o /dev/null -I --max-time "$timeout" --connect-timeout "$ctimeout" -k "$url_hs" >/dev/null 2>&1
    else
      curl -sS -o /dev/null -I --max-time "$timeout" --connect-timeout "$ctimeout" "$url_hs" >/dev/null 2>&1
    fi
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
      _probe_one_url "$url_hs" "$methods"
    else
      _probe_one_url "$url_h" "$methods"
    fi
  }

  if [[ -n "$custom_ports" ]]; then
    # Extract bare hostname (strip any existing :port)
    local bare_host="$target"
    bare_host="${bare_host%%:*}"

    IFS=',' read -r -a port_list <<< "$custom_ports"
    for port in "${port_list[@]}"; do
      port="$(echo "$port" | tr -d '[:space:]')"
      [[ -z "$port" ]] && continue
      if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        >&2 echo "WARNING: некорректный порт '$port', пропускаем"
        continue
      fi

      echo ""
      printf '%b\n' "${C_BOLD}========== Порт $port ==========${C_RESET}"

      case "$mode" in
        fixed)
          local scheme="${base_url%%://*}"
          _probe_one_url "$(_build_url_with_port "$scheme" "$bare_host" "$port" "$path")" "$methods"
          ;;
        http)
          _probe_one_url "$(_build_url_with_port "http" "$bare_host" "$port" "$path")" "$methods"
          ;;
        https)
          _probe_one_url "$(_build_url_with_port "https" "$bare_host" "$port" "$path")" "$methods"
          ;;
        auto)
          _probe_auto \
            "$(_build_url_with_port "http"  "$bare_host" "$port" "$path")" \
            "$(_build_url_with_port "https" "$bare_host" "$port" "$path")"
          ;;
      esac
    done
  else
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
        _probe_auto "$url_http" "$url_https"
        ;;
      *)
        echo "Внутренняя ошибка: неизвестный режим '$mode'"
        return 2
        ;;
    esac
  fi
}
