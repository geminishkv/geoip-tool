#!/usr/bin/env bash
set -euo pipefail

_cmd_scan_help() {
  cat <<'EOF'
Использование:
  geoip scan [опции] <IP|host|CIDR>

Опции:
  --top-ports N            Сканировать N самых популярных портов (по умолчанию 100)
  --ports PORTS            Указать порты вручную, напр. 22,80,443 или 1-1024
  --scan-type TYPE         Тип сканирования: quick, full, stealth (по умолчанию quick)
  --with-lookup            Выполнить GeoIP lookup для найденных IP
  --nmap-args "ARGS"       Передать дополнительные аргументы nmap
  --xml-output FILE        Сохранить XML-вывод nmap в файл
  -h, --help               Справка

Типы сканирования:
  quick    -sT --top-ports N (TCP connect, быстро)
  full     -sT -p- (все 65535 портов)
  stealth  -sS --top-ports N (SYN scan, требует root/sudo)

Примеры:
  geoip scan 192.168.1.0/24
  geoip scan --scan-type stealth --top-ports 1000 target.com
  geoip scan --with-lookup 8.8.8.8
  geoip scan --ports 80,443,8080 example.com
EOF
}

cmd_scan() {
  local top_ports="100"
  local custom_ports=""
  local scan_type="quick"
  local with_lookup=0
  local extra_args=""
  local xml_output=""
  local target=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _cmd_scan_help
        return 0
        ;;
      --top-ports)  shift; top_ports="${1:-100}"; shift ;;
      --ports)      shift; custom_ports="${1:-}"; shift ;;
      --scan-type)  shift; scan_type="${1:-quick}"; shift ;;
      --with-lookup) with_lookup=1; shift ;;
      --nmap-args)  shift; extra_args="${1:-}"; shift ;;
      --xml-output) shift; xml_output="${1:-}"; shift ;;
      --)           shift; break ;;
      --*)
        echo "Неизвестная опция: $1" >&2
        _cmd_scan_help
        return 2
        ;;
      *)
        if [[ -z "$target" ]]; then
          target="$1"; shift
        else
          echo "Лишний аргумент: $1" >&2
          _cmd_scan_help
          return 2
        fi
        ;;
    esac
  done

  if [[ -z "$target" ]]; then
    >&2 echo "ERROR: необходима цель (IP, хост или CIDR)"
    _cmd_scan_help
    return 2
  fi

  if ! command -v nmap &>/dev/null; then
    >&2 echo "ERROR: nmap не установлен или не найден в PATH"
    >&2 echo "Установка:"
    >&2 echo "  Debian/Ubuntu: sudo apt install nmap"
    >&2 echo "  Alpine:        apk add nmap"
    >&2 echo "  macOS:         brew install nmap"
    >&2 echo "  Windows:       https://nmap.org/download.html"
    return 1
  fi

  local nmap_cmd=(nmap)

  case "$scan_type" in
    quick)
      nmap_cmd+=(-sT)
      if [[ -n "$custom_ports" ]]; then
        nmap_cmd+=(-p "$custom_ports")
      else
        nmap_cmd+=(--top-ports "$top_ports")
      fi
      ;;
    full)
      nmap_cmd+=(-sT -p-)
      ;;
    stealth)
      nmap_cmd+=(-sS)
      if [[ -n "$custom_ports" ]]; then
        nmap_cmd+=(-p "$custom_ports")
      else
        nmap_cmd+=(--top-ports "$top_ports")
      fi
      ;;
    *)
      >&2 echo "ERROR: неизвестный тип сканирования '$scan_type' (quick, full, stealth)"
      return 2
      ;;
  esac

  local tmp_xml
  tmp_xml=$(mktemp "${TMPDIR:-/tmp}/geoip_nmap_XXXXXX.xml")

  nmap_cmd+=(-oX "$tmp_xml")

  if [[ -n "$extra_args" ]]; then
    # shellcheck disable=SC2086
    nmap_cmd+=($extra_args)
  fi

  nmap_cmd+=("$target")

  >&2 echo "[scan] Запуск: ${nmap_cmd[*]}"
  >&2 echo ""

  set +e
  "${nmap_cmd[@]}"
  local rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    >&2 echo "[scan] nmap завершился с кодом $rc"
    rm -f "$tmp_xml"
    return $rc
  fi

  if [[ -n "$xml_output" ]]; then
    cp "$tmp_xml" "$xml_output"
    >&2 echo "[scan] XML сохранён в $xml_output"
  fi

  echo ""
  echo "=== Результаты сканирования ==="
  echo ""

  local ips
  ips=$(grep -oP 'addr="\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$tmp_xml" | sort -u || true)

  if [[ -n "$ips" ]]; then
    echo "Обнаруженные хосты:"
    for ip in $ips; do
      echo "  $ip"
      grep -B1 'state="open"' "$tmp_xml" \
        | grep '<port ' \
        | sed 's/.*protocol="\([^"]*\)".*portid="\([^"]*\)".*/    \1\/\2 open/' 2>/dev/null || true
    done
  else
    echo "  Хосты не обнаружены"
  fi

  if [[ "$with_lookup" == "1" && -n "$ips" ]]; then
    echo ""
    echo "=== GeoIP Lookup для обнаруженных хостов ==="
    for ip in $ips; do
      echo ""
      echo "--- $ip ---"
      cmd_lookup "$ip"
      sleep 1
    done
  fi

  rm -f "$tmp_xml"
}
