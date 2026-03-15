#!/usr/bin/env bash
set -euo pipefail

_cmd_asn_help() {
  _banner
  printf "  ${C_DIM}ASN & BGP разведка через RIPE Stat${C_RESET}\n"

  _h "Использование"
  _exm "geoip asn [подкоманда] [опции] <IP|ASN>"

  _h "Подкоманды"
  _opt "info (по умолчанию)" "ASN, holder, тип, анонсируемые префиксы"
  _opt "peers" "BGP-соседи (upstream, downstream, uncertain)"
  _opt "prefix" "Routing status, visibility, RPKI валидация"

  _h "Опции"
  _opt "--json" "Вывод в формате JSON"
  _opt "-h, --help" "Справка"

  _h "Примеры"
  _exm "geoip asn 8.8.8.8"
  _exm "geoip asn info AS15169"
  _exm "geoip asn peers AS15169"
  _exm "geoip asn peers 8.8.8.8"
  _exm "geoip asn prefix 8.8.8.8"
  _exm "geoip asn --json peers AS15169"
  echo ""
}

# ── RIPE Stat API хелперы ──

_ripe_network_info() {
  curl -sS --max-time 15 "https://stat.ripe.net/data/network-info/data.json?resource=${1}"
}

_ripe_as_overview() {
  curl -sS --max-time 15 "https://stat.ripe.net/data/as-overview/data.json?resource=AS${1}"
}

_ripe_announced_prefixes() {
  curl -sS --max-time 15 "https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS${1}"
}

_ripe_asn_neighbours() {
  curl -sS --max-time 15 "https://stat.ripe.net/data/asn-neighbours/data.json?resource=AS${1}"
}

_ripe_routing_status() {
  curl -sS --max-time 15 "https://stat.ripe.net/data/routing-status/data.json?resource=${1}"
}

_ripe_rpki_validation() {
  local asn="$1" prefix="$2"
  curl -sS --max-time 15 "https://stat.ripe.net/data/rpki-validation/data.json?resource=AS${asn}&prefix=${prefix}"
}

# ── Резолв target → ASN + prefix ──

_resolve_target_to_asn() {
  local target="$1"
  # Результаты через глобальные переменные
  _RESOLVED_ASN=""
  _RESOLVED_PREFIX="-"

  local clean="${target#AS}"
  clean="${clean#as}"

  if [[ "$clean" =~ ^[0-9]+$ ]]; then
    _RESOLVED_ASN="$clean"
  else
    local network_info
    network_info=$(_ripe_network_info "$target")

    local status
    status=$(echo "$network_info" | jq -r '.status // "error"')
    if [[ "$status" != "ok" ]]; then
      printf '%b\n' "${C_RED}ERROR: RIPE Stat вернул статус: ${status}${C_RESET}" >&2
      return 1
    fi

    _RESOLVED_ASN=$(echo "$network_info" | jq -r '.data.asns[0] // empty')
    _RESOLVED_PREFIX=$(echo "$network_info" | jq -r '.data.prefix // "-"')

    if [[ -z "$_RESOLVED_ASN" ]]; then
      printf '%b\n' "${C_RED}ERROR: не удалось определить ASN для ${target}${C_RESET}" >&2
      return 1
    fi
  fi
}

# ── Подкоманда: info (по умолчанию) ──

_asn_info() {
  local target="$1" json_mode="$2"

  _resolve_target_to_asn "$target"
  local asn="$_RESOLVED_ASN"
  local prefix="$_RESOLVED_PREFIX"

  local overview prefixes
  overview=$(_ripe_as_overview "$asn")
  prefixes=$(_ripe_announced_prefixes "$asn")

  if [[ "$json_mode" == "1" ]]; then
    local tmp_ov tmp_pf
    tmp_ov=$(mktemp)
    tmp_pf=$(mktemp)
    echo "$overview" > "$tmp_ov"
    echo "$prefixes" > "$tmp_pf"
    jq -n --arg t "$target" --arg a "$asn" --arg p "$prefix" \
      --slurpfile ov "$tmp_ov" \
      --slurpfile pf "$tmp_pf" \
      '{query: $t, asn: ("AS" + $a)}
       + (if $p != "-" then {prefix: $p} else {} end)
       + {overview: $ov[0].data, prefixes: [$pf[0].data.prefixes[] | {prefix: .prefix}]}'
    rm -f "$tmp_ov" "$tmp_pf"
    return 0
  fi

  # Pretty
  if [[ "$prefix" != "-" ]]; then
    printf '%b\n' "${C_CYAN}IP:${C_RESET}          ${target}"
    printf '%b\n' "${C_CYAN}Префикс:${C_RESET}     ${prefix}"
  fi

  local holder type
  holder=$(echo "$overview" | jq -r '.data.holder // "-"')
  type=$(echo "$overview" | jq -r '.data.type // "-"')

  printf '%b\n' "${C_CYAN}ASN:${C_RESET}         AS${asn}"
  printf '%b\n' "${C_CYAN}Holder:${C_RESET}      ${holder}"
  printf '%b\n' "${C_CYAN}Тип:${C_RESET}         ${type}"

  local count
  count=$(echo "$prefixes" | jq -r '.data.prefixes | length // 0')
  printf '%b\n' "${C_CYAN}Префиксов:${C_RESET}   ${count}"

  if (( count > 0 )); then
    echo ""
    printf '%b\n' "${C_BOLD}Анонсируемые префиксы:${C_RESET}"
    echo "$prefixes" | jq -r '.data.prefixes[:20][] | "  \(.prefix)  \(.timelines[0].starttime // "-")"' 2>/dev/null || true
    if (( count > 20 )); then
      printf '%b\n' "  ${C_DIM}... и ещё $((count - 20)) префиксов${C_RESET}"
    fi
  fi
}

# ── Подкоманда: peers ──

_asn_peers() {
  local target="$1" json_mode="$2"

  _resolve_target_to_asn "$target"
  local asn="$_RESOLVED_ASN"

  local neighbours
  neighbours=$(_ripe_asn_neighbours "$asn")

  if [[ "$json_mode" == "1" ]]; then
    # Собираем JSON через pipe — neighbours может быть очень большим
    echo "$neighbours" | jq --arg t "$target" --arg a "$asn" \
      '{query: $t, asn: ("AS" + $a), neighbours: .data.neighbours}'
    return 0
  fi

  # Pretty
  local overview
  overview=$(_ripe_as_overview "$asn")
  local holder
  holder=$(echo "$overview" | jq -r '.data.holder // "-"')

  printf '%b\n' "${C_CYAN}ASN:${C_RESET}         AS${asn} (${holder})"

  local total
  total=$(echo "$neighbours" | jq -r '.data.neighbours | length // 0')
  printf '%b\n' "${C_CYAN}Соседей:${C_RESET}     ${total}"
  echo ""

  # Upstream (left)
  local left_count
  left_count=$(echo "$neighbours" | jq '[.data.neighbours[] | select(.type == "left")] | length')
  if (( left_count > 0 )); then
    printf '%b\n' "${C_BOLD}▶ Upstream (left): ${left_count}${C_RESET}"
    echo "$neighbours" | jq -r '.data.neighbours[] | select(.type == "left") | "  AS\(.asn)\t\(.power)"' | sort -t$'\t' -k2 -rn | head -20 | while IFS=$'\t' read -r asn_str power; do
      printf "  ${C_GREEN}%-12s${C_RESET} power: %s\n" "$asn_str" "$power"
    done
    echo ""
  fi

  # Downstream (right)
  local right_count
  right_count=$(echo "$neighbours" | jq '[.data.neighbours[] | select(.type == "right")] | length')
  if (( right_count > 0 )); then
    printf '%b\n' "${C_BOLD}▶ Downstream (right): ${right_count}${C_RESET}"
    echo "$neighbours" | jq -r '.data.neighbours[] | select(.type == "right") | "  AS\(.asn)\t\(.power)"' | sort -t$'\t' -k2 -rn | head -20 | while IFS=$'\t' read -r asn_str power; do
      printf "  ${C_YELLOW}%-12s${C_RESET} power: %s\n" "$asn_str" "$power"
    done
    echo ""
  fi

  # Uncertain
  local unc_count
  unc_count=$(echo "$neighbours" | jq '[.data.neighbours[] | select(.type == "uncertain")] | length')
  if (( unc_count > 0 )); then
    printf '%b\n' "${C_BOLD}▶ Uncertain: ${unc_count}${C_RESET}"
    echo "$neighbours" | jq -r '.data.neighbours[] | select(.type == "uncertain") | "  AS\(.asn)\t\(.power)"' | sort -t$'\t' -k2 -rn | head -20 | while IFS=$'\t' read -r asn_str power; do
      printf "  ${C_DIM}%-12s${C_RESET} power: %s\n" "$asn_str" "$power"
    done
    echo ""
  fi

  local shown=$((left_count > 20 ? 20 : left_count))
  shown=$((shown + (right_count > 20 ? 20 : right_count)))
  shown=$((shown + (unc_count > 20 ? 20 : unc_count)))
  if (( total > shown )); then
    printf '%b\n' "${C_DIM}Показано ${shown} из ${total} (по 20 в каждой группе)${C_RESET}"
  fi
}

# ── Подкоманда: prefix ──

_asn_prefix() {
  local target="$1" json_mode="$2"

  _resolve_target_to_asn "$target"
  local asn="$_RESOLVED_ASN"
  local prefix="$_RESOLVED_PREFIX"

  # Если target — номер ASN, нужен хотя бы один prefix
  if [[ "$prefix" == "-" ]]; then
    local prefixes_resp
    prefixes_resp=$(_ripe_announced_prefixes "$asn")
    prefix=$(echo "$prefixes_resp" | jq -r '.data.prefixes[0].prefix // empty' 2>/dev/null)
    if [[ -z "$prefix" ]]; then
      printf '%b\n' "${C_RED}ERROR: не найден prefix для AS${asn}${C_RESET}" >&2
      return 1
    fi
  fi

  local routing rpki
  routing=$(_ripe_routing_status "$prefix")
  rpki=$(_ripe_rpki_validation "$asn" "$prefix")

  if [[ "$json_mode" == "1" ]]; then
    local result='{}'
    result=$(echo "$result" | jq --arg t "$target" --arg a "$asn" --arg p "$prefix" \
      '. + {query: $t, asn: ("AS" + $a), prefix: $p}')
    if echo "$routing" | jq -e '.data' >/dev/null 2>&1; then
      result=$(echo "$result" | jq --argjson v "$(echo "$routing" | jq '.data')" '. + {routing: $v}')
    fi
    if echo "$rpki" | jq -e '.data' >/dev/null 2>&1; then
      result=$(echo "$result" | jq --argjson v "$(echo "$rpki" | jq '.data')" '. + {rpki: $v}')
    fi
    echo "$result" | jq '.'
    return 0
  fi

  # Pretty
  local overview
  overview=$(_ripe_as_overview "$asn")
  local holder
  holder=$(echo "$overview" | jq -r '.data.holder // "-"')

  printf '%b\n' "${C_CYAN}Prefix:${C_RESET}      ${prefix}"
  printf '%b\n' "${C_CYAN}Origin AS:${C_RESET}   AS${asn} (${holder})"

  # Routing status
  local first_seen last_seen
  first_seen=$(echo "$routing" | jq -r '.data.first_seen.time // "-"' 2>/dev/null || echo "-")
  last_seen=$(echo "$routing" | jq -r '.data.last_seen.time // "-"' 2>/dev/null || echo "-")

  # Определяем announced по visibility
  local vis_check
  vis_check=$(echo "$routing" | jq -r '.data.visibility.v4.ris_peers_seeing // 0' 2>/dev/null || echo "0")
  if (( vis_check > 0 )); then
    printf '%b\n' "${C_CYAN}Статус:${C_RESET}      ${C_GREEN}Announced${C_RESET}"
  else
    printf '%b\n' "${C_CYAN}Статус:${C_RESET}      ${C_RED}Not announced${C_RESET}"
  fi

  printf '%b\n' "${C_CYAN}First seen:${C_RESET}  ${first_seen}"
  printf '%b\n' "${C_CYAN}Last seen:${C_RESET}   ${last_seen}"

  # Visibility
  local vis_v4 vis_v6
  vis_v4=$(echo "$routing" | jq -r '.data.visibility.v4.ris_peers_seeing // 0' 2>/dev/null || echo "0")
  vis_v6=$(echo "$routing" | jq -r '.data.visibility.v6.ris_peers_seeing // 0' 2>/dev/null || echo "0")
  local total_v4 total_v6
  total_v4=$(echo "$routing" | jq -r '.data.visibility.v4.total_ris_peers // 0' 2>/dev/null || echo "0")
  total_v6=$(echo "$routing" | jq -r '.data.visibility.v6.total_ris_peers // 0' 2>/dev/null || echo "0")

  if (( total_v4 > 0 )); then
    local pct=$(( vis_v4 * 100 / total_v4 ))
    printf '%b\n' "${C_CYAN}IPv4 vis:${C_RESET}    ${vis_v4}/${total_v4} RIS peers (${pct}%)"
  fi
  if (( total_v6 > 0 )); then
    local pct=$(( vis_v6 * 100 / total_v6 ))
    printf '%b\n' "${C_CYAN}IPv6 vis:${C_RESET}    ${vis_v6}/${total_v6} RIS peers (${pct}%)"
  fi

  # RPKI
  local rpki_status
  rpki_status=$(echo "$rpki" | jq -r '.data.validating_roas[0].validity // .data.status // "-"' 2>/dev/null || echo "-")
  case "$rpki_status" in
    valid)
      printf '%b\n' "${C_CYAN}RPKI:${C_RESET}        ${C_GREEN}Valid${C_RESET}"
      ;;
    invalid*)
      printf '%b\n' "${C_CYAN}RPKI:${C_RESET}        ${C_RED}Invalid${C_RESET}"
      ;;
    *)
      printf '%b\n' "${C_CYAN}RPKI:${C_RESET}        ${C_DIM}${rpki_status}${C_RESET}"
      ;;
  esac
}

# ── Главная точка входа ──

cmd_asn() {
  local subcmd=""
  local target=""
  local json_mode=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        _cmd_asn_help
        return 0
        ;;
      --json)  json_mode=1; shift ;;
      --)      shift; break ;;
      --*)
        echo "Неизвестная опция: $1" >&2
        _cmd_asn_help
        return 2
        ;;
      info|peers|prefix)
        if [[ -z "$subcmd" ]]; then
          subcmd="$1"; shift
        elif [[ -z "$target" ]]; then
          target="$1"; shift
        else
          echo "Лишний аргумент: $1" >&2
          return 2
        fi
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

  # По умолчанию — info
  [[ -z "$subcmd" ]] && subcmd="info"

  if [[ -z "$target" ]]; then
    >&2 echo "ERROR: необходим IP-адрес или номер ASN"
    _cmd_asn_help
    return 2
  fi

  case "$subcmd" in
    info)   _asn_info "$target" "$json_mode" ;;
    peers)  _asn_peers "$target" "$json_mode" ;;
    prefix) _asn_prefix "$target" "$json_mode" ;;
  esac
}
