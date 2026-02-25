#!/usr/bin/env bash
set -euo pipefail

cmd_http() {
  local target="${1:-}"
  shift || true

  if [[ -z "$target" ]]; then
    echo "Usage: geoip http <IP|host[:port]> [--https] [--path /] [--methods CSV] [--timeout SEC] [--connect-timeout SEC] [--follow] [--insecure] [--aggressive]"
    exit 1
  fi

  local scheme="http"
  local path="/"
  local methods="GET,HEAD,OPTIONS"
  local timeout="10"
  local ctimeout="5"
  local follow="0"
  local insecure="0"
  local aggressive="0"

  while [[ "${1:-}" == --* ]]; do
    case "$1" in
      --https) scheme="https" ;;
      --path) shift; path="${1:-/}" ;;
      --methods) shift; methods="${1:-GET,HEAD,OPTIONS}" ;;
      --timeout) shift; timeout="${1:-10}" ;;
      --connect-timeout) shift; ctimeout="${1:-5}" ;;
      --follow) follow="1" ;;
      --insecure) insecure="1" ;;
      --aggressive) aggressive="1" ;;
      --help|-h) echo "Usage: geoip http <target> [--https] [--path /] [--methods CSV] [--timeout SEC] [--connect-timeout SEC] [--follow] [--insecure] [--aggressive]"; return 0 ;;
      *) echo "Unknown option: $1"; return 2 ;;
    esac
    shift || true
  done

  if [[ "$aggressive" == "1" ]]; then
    methods="GET,HEAD,OPTIONS,POST,PUT,DELETE,TRACE"
  fi

  [[ "${path:0:1}" != "/" ]] && path="/$path"

  local url="${scheme}://${target}${path}"

  echo "[*] HTTP method probing: $url"
  echo "[*] methods=$methods timeout=${timeout}s connect-timeout=${ctimeout}s follow=$follow insecure=$insecure"
  echo

  IFS=',' read -r -a mlist <<< "$methods"

  for method in "${mlist[@]}"; do
    method="$(echo "$method" | tr -d '[:space:]')"
    [[ -z "$method" ]] && continue

    echo "===== $method ====="

    local tmp_headers rc
    tmp_headers="$(mktemp)"
    local curl_args=(-sS -o /dev/null -D "$tmp_headers" -X "$method" "--max-time" "$timeout" "--connect-timeout" "$ctimeout")

    [[ "$follow" == "1" ]] && curl_args+=(-L)
    [[ "$insecure" == "1" ]] && curl_args+=(-k)

    if curl "${curl_args[@]}" "$url"; then
      tr -d '\r' < "$tmp_headers" | head -n 1
      tr -d '\r' < "$tmp_headers" | awk 'BEGIN{IGNORECASE=1} /^server:|^allow:|^location:|^content-type:|^content-length:/ {print}'
    else
      rc=$?
      echo "curl error (exit code $rc)"
    fi

    rm -f "$tmp_headers"
    echo
  done
}