#!/usr/bin/env bash
set -euo pipefail

_cmd_recon_help() {
  cat <<'EOF'
Использование:
  geoip recon [опции] <IP|домен>

Полная разведка цели — сбор информации из нескольких модулей одной командой.

Опции:
  --modules LIST    Модули через запятую (по умолчанию: lookup,reverse,dns,whois)
  --full            Все модули (+ abuse, http)
  --json            JSON вывод (объединённый)
  -h, --help        Справка

Доступные модули:
  lookup    GeoIP lookup
  reverse   Reverse IP (домены на IP)
  dns       DNS-записи
  whois     WHOIS информация
  abuse     AbuseIPDB (требует API-ключ)
  http      HTTP-пробинг методов

Примеры:
  geoip recon 8.8.8.8
  geoip recon --full 8.8.8.8
  geoip recon --modules lookup,dns example.com
  geoip recon --json 8.8.8.8
EOF
}

cmd_recon() {
  local target=""
  local modules="lookup,reverse,dns,whois"
  local json_mode=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _cmd_recon_help
        return 0
        ;;
      --modules)  shift; modules="${1:-lookup,reverse,dns,whois}"; shift ;;
      --modules=*) modules="${1#*=}"; shift ;;
      --full)     modules="lookup,reverse,dns,whois,abuse,http"; shift ;;
      --json)     json_mode=1; shift ;;
      --)         shift; break ;;
      --*)
        echo "Неизвестная опция: $1" >&2
        _cmd_recon_help
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
    >&2 echo "ERROR: необходима цель (IP или домен)"
    _cmd_recon_help
    return 2
  fi

  IFS=',' read -r -a mod_list <<< "$modules"

  if [[ "$json_mode" == "1" ]]; then
    _recon_json "$target" "${mod_list[@]}"
    return 0
  fi

  printf '%b\n' "${C_BOLD}╔══════════════════════════════════════╗${C_RESET}"
  printf '%b\n' "${C_BOLD}║   RECON: $target${C_RESET}"
  printf '%b\n' "${C_BOLD}╚══════════════════════════════════════╝${C_RESET}"
  echo ""

  for mod in "${mod_list[@]}"; do
    mod=$(echo "$mod" | tr -d '[:space:]')
    [[ -z "$mod" ]] && continue

    case "$mod" in
      lookup)
        printf '%b\n' "${C_BOLD}▶ GeoIP Lookup${C_RESET}"
        echo ""
        set +e; cmd_lookup "$target"; set -e
        echo ""
        ;;
      reverse)
        printf '%b\n' "${C_BOLD}▶ Reverse IP Lookup${C_RESET}"
        echo ""
        set +e; cmd_reverse "$target"; set -e
        echo ""
        ;;
      dns)
        printf '%b\n' "${C_BOLD}▶ DNS Records${C_RESET}"
        echo ""
        set +e; cmd_dns "$target"; set -e
        echo ""
        ;;
      whois)
        printf '%b\n' "${C_BOLD}▶ WHOIS${C_RESET}"
        echo ""
        set +e; cmd_whois "$target"; set -e
        echo ""
        ;;
      abuse)
        if [[ -z "${ABUSEIPDB_API_KEY:-}" ]]; then
          printf '%b\n' "${C_BOLD}▶ AbuseIPDB${C_RESET}"
          printf '%b\n' "  ${C_YELLOW}Пропущено: ABUSEIPDB_API_KEY не задан${C_RESET}"
          echo ""
        else
          printf '%b\n' "${C_BOLD}▶ AbuseIPDB${C_RESET}"
          echo ""
          set +e; cmd_abuse "$target"; set -e
          echo ""
        fi
        ;;
      http)
        printf '%b\n' "${C_BOLD}▶ HTTP Probe${C_RESET}"
        echo ""
        set +e; cmd_http "$target"; set -e
        echo ""
        ;;
      *)
        printf '%b\n' "${C_YELLOW}Неизвестный модуль: $mod (пропущено)${C_RESET}"
        echo ""
        ;;
    esac
  done

  printf '%b\n' "${C_BOLD}══════════════════════════════════════${C_RESET}"
  printf '%b\n' "${C_DIM}Recon завершён для $target${C_RESET}"
}

_recon_json() {
  local target="$1"
  shift
  local mods=("$@")
  local result='{"target":"'"$target"'"}'

  for mod in "${mods[@]}"; do
    mod=$(echo "$mod" | tr -d '[:space:]')
    [[ -z "$mod" ]] && continue

    local mod_output=""

    case "$mod" in
      lookup)
        set +e
        mod_output=$(provider_request_with_cache "$target" "$DEFAULT_LANG" 2>/dev/null)
        set -e
        if echo "$mod_output" | jq -e 'type=="object"' >/dev/null 2>&1; then
          result=$(echo "$result" | jq --argjson v "$mod_output" '. + {lookup: $v}')
        fi
        ;;
      reverse)
        set +e
        mod_output=$(cmd_reverse --json "$target" 2>/dev/null)
        set -e
        if [[ -n "$mod_output" ]]; then
          local parsed
          if parsed=$(echo "$mod_output" | jq -e '.' 2>/dev/null); then
            result=$(echo "$result" | jq --argjson v "$parsed" '. + {reverse: $v}')
          fi
        fi
        ;;
      dns)
        set +e
        mod_output=$(cmd_dns --json "$target" 2>/dev/null)
        set -e
        if echo "$mod_output" | jq -e 'type=="object"' >/dev/null 2>&1; then
          result=$(echo "$result" | jq --argjson v "$mod_output" '. + {dns: $v}')
        fi
        ;;
      whois)
        set +e
        mod_output=$(cmd_whois --json "$target" 2>/dev/null)
        set -e
        if echo "$mod_output" | jq -e 'type=="object"' >/dev/null 2>&1; then
          result=$(echo "$result" | jq --argjson v "$mod_output" '. + {whois: $v}')
        fi
        ;;
      abuse)
        if [[ -n "${ABUSEIPDB_API_KEY:-}" ]]; then
          set +e
          mod_output=$(cmd_abuse --json "$target" 2>/dev/null)
          set -e
          if echo "$mod_output" | jq -e 'type=="object"' >/dev/null 2>&1; then
            result=$(echo "$result" | jq --argjson v "$mod_output" '. + {abuse: $v}')
          fi
        fi
        ;;
    esac
  done

  echo "$result" | jq '.'
}
