#!/usr/bin/env bash
set -euo pipefail

cmd_http() {
  local target="${1:-}"
  if [[ -z "$target" ]]; then
    echo "Usage: geoip http <IP|host>"
    exit 1
  fi

  local url="http://$target"

  echo "[*] Тестируем HTTP-методы для $url"
  echo

  for method in GET POST PUT DELETE HEAD OPTIONS TRACE; do
    echo "===== $method ====="
    if [[ "$method" == "HEAD" ]]; then
      if ! curl -s -o /dev/null -D - -X HEAD "$url"; then
        echo "Ошибка запроса (HEAD)"
      fi
    else
      if ! curl -s -o /dev/null -D - -X "$method" "$url"; then
        echo "Ошибка запроса ($method)"
      fi
    fi
    echo
  done
}