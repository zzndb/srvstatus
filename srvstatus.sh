#!/usr/bin/env bash
#
# optional list dir
# output: service name
#         status num; active 1, inactive 3, failed 4, other 0
#         status_time second

SLISTF='service_list'
ULISTF='user_service_list'
SLIST=()
ULIST=()
SQCMDH='systemctl status '
UQCMDH='systemctl --user status '
CMDT=' -n 0' # disable journal log output
OUT=''

err_exit() {
    echo "$1"
    exit
}

parse_list() {
    if [[ ! -f $SLISTF ]]; then
        err_exit "can not found service list file '$SLISTF'"
    fi
    SLIST="$(cat $SLISTF)"
    # for user service
    [[ -f $ULISTF ]] && ULIST="$(cat $ULISTF)"
}

query_all() {
    OUT='['
    for i in $SLIST; do
        query_info "$SQCMDH""$i""$CMDT"
        # echo "service=$i,"$out
        OUT=$OUT'{'"\"service\":\"$i.service\","$out'},'
    done
    for i in $ULIST; do
        query_info "$UQCMDH""$i""$CMDT"
        # echo "service=$i,"$out
        OUT=$OUT'{'"\"service\":\"$i.service\","$out'},'
    done
    OUT=${OUT%*,}
    OUT=$OUT']'
    echo "$OUT"
}

query_info() {
    local info
    info=$($1)
    info="$(echo -e "$info" | sed -n '3s/.*Active:\ \(.*\).*/\1/p')"
    # echo $info 
    status=${info%% since*}
    if [[ $status == "active (running)" ]]; then
        out="1"
    elif [[ $status == "inactive (dead)" ]]; then
        out="3"
    elif [[ $status =~ "failed" ]]; then
        out="4"
    else
        out="0"
    fi
    # echo "'"$status"'"
    if [[ $info =~ "since" ]]; then
        status_time=$(echo "$info" | sed -n 's/.*[a-zA-Z]\{3\} \([0-9 :-]*[A-Z]\{3\}\);.*/\1/p')
        status_time=$(($(date '+%s') - $(date --date="$status_time" '+%s')))
        # echo "'"$status_time"'"
    else 
        status_time=0
    fi
    out="\"status\":$out,\"status_time\":$status_time"
}

pushd "$(dirname "$0")" &>/dev/null || exit
parse_list
query_all
popd &>/dev/null || exit
