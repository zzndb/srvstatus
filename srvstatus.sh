#!/usr/bin/env bash
# by zzndb
# output: service name
#         status num; active 1, inactive 3, failed 4, other 0
#         status_time second
#         memory bytes (if listed by systemctl)
# input: service list require each line contains an element
#
set -euo pipefail

Influx_measurement='services_stats'
# maybe you need change this
Uid='1000'

SLISTF='service_list'
ULISTF='user_service_list'
SLIST=()
ULIST=()
SQCMDH='systemctl show '
UQCMDH='sudo -Eu '$(id -un $Uid)' systemctl --user show '
CMDT=' --property=ActiveState,ActiveEnterTimestamp,ActiveExitTimestamp,MemoryCurrent'
OUT=''

set_user_dbus_info() {
    export XDG_RUNNING_DIR="/run/user/$Uid/"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNNING_DIR}/bus"
}

err_exit() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
    exit
}

parse_list() {
    if [[ ! -f $SLISTF ]]; then
        err_exit "can not found service list file '$SLISTF'"
    fi
    mapfile -t SLIST < $SLISTF
    # for user service
    [[ -f $ULISTF ]] && set_user_dbus_info && mapfile -t ULIST < $ULISTF
}

query_all() {
    for i in "${SLIST[@]}"; do
        i=$(tr -d '[:cntrl:],[:space:],[:blank:]' <<< "$i")
        [[ $i == "" ]] && continue
        query_info "$SQCMDH""$i""$CMDT"
        # echo "service=$i,"$out
        OUT=$Influx_measurement",service=$i "$out
        echo "$OUT"
    done
    for i in "${ULIST[@]}"; do
        i=$(tr -d '[:cntrl:],[:space:],[:blank:]' <<< "$i")
        [[ $i == "" ]] && continue
        query_info "$UQCMDH""$i""$CMDT"
        # echo "service=$i,"$out
        OUT=$Influx_measurement",service=$i "$out
        echo "$OUT"
    done
}

query_info() {
    local info
    info=$($1)
    #1. STATUS
    info_status="$(grep ActiveState <<< "$info")"
    status=${info_status#*=}
    if [[ $status == "active" ]]; then
        out="1"
    elif [[ $status == "inactive" ]]; then
        out="3"
    elif [[ $status =~ "failed" ]]; then
        out="4"
    else
        out="0"
    fi
    #2. STATUS_TIME
    if [[ $out == "1" ]]; then
        info_time="$(grep ActiveEnterTimestamp <<< "$info")"
    else
        info_time="$(grep ActiveExitTimestamp <<< "$info")"
    fi
    if [[ ${info_time#*=} != "" ]]; then
        status_time=$(($(date '+%s') - $(date --date="${info_time#*=}" '+%s')))
    else
        status_time=0
    fi
    out="status=$out,status_time=$status_time"
    #3. Memory used
    # empty, [not set], bytes num
    info_memory="$(grep MemoryCurrent <<< "$info")"
    memory="${info_memory#*=}"
    if [[ $memory != "" && $memory != "[not set]" ]]; then
        out="$out,memory=$memory"
    fi
}

main() {
    pushd "$(dirname "$0")" &>/dev/null || exit
    parse_list
    query_all
    popd &>/dev/null || exit
}

main "$@"
