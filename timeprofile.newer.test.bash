gg() {
(
local -ai tDiffA0 tDiffA1
local -a tCmdA
local -i LASTNO 
local tDiffOut t0 PREV_CMD PREV_LINENO

shopt -s extglob
set -T

tic() { 
    t0=${EPOCHREALTIME}; 
}
toc() { 
    local t1 
    t1=${EPOCHREALTIME}; 
    [[ ${3} == 1 ]] || {
        PREV_LINENO="${1}"
        PREV_CMD+=$'\n'"${2}"  
    }
    [[ -n ${PREV_LINENO} ]] && {
        [[ -n ${tDiffA0[${PREV_LINENO}]} ]] || tDiffA0[${PREV_LINENO}]=0
        [[ -n ${tDiffA1[${PREV_LINENO}]} ]] || tDiffA1[${PREV_LINENO}]=0
        tDiffA0[${PREV_LINENO}]+=$(( ${t1%.*} - ${t0%.*} ))
        tDiffA1[${PREV_LINENO}]+=$(( ${t1##*.*(0)} - ${t0##*.*(0)} ))
    }
    [[ -n ${PREV_CMD} ]] && tCmdA[${PREV_LINENO}]+=$'\n'"${PREV_CMD}" 
    if [[ ${3} == 1 ]]; then
        PREV_LINENO="${1}"
        PREV_CMD="${2}"
    else
        PREV_LINENO=''
        PREV_CMD=''
    fi
    t0=${EPOCHREALTIME}

}
fExit() {
    local kk
    for kk in ${!tDiffA1[@]}; do
        while (( ${tDiffA1[$kk]} < 0 )); do
            ((tDiffA0[$kk]--))
            tDiffA1[$kk]=$(( ${tDiffA1[$kk]} + 1000000 ))
        done
        while (( ${tDiffA1[$kk]} >= 1000000 )); do
            ((tDiffA0[$kk]++))
            tDiffA1[$kk]=$(( ${tDiffA1[$kk]} - 1000000 ))
        done
        tCmdA[$kk]="$(echo "${tCmdA[$kk]}" | sort | uniq -c | tail -n +2 | sed -E s/'^[ \t]*([0-9]+) '/'(\1x) '/)"
        
        printf '%d: %d.%06d sec \t{ %s }\n' "${kk}" "${tDiffA0[$kk]}" "${tDiffA1[$kk]}" "$(IFS=$'\n'; printf '%s;  ' ${tCmdA[$kk]})"
    done
}
getCurTrap() {
    local nn
    parseTrap() (
        echo "$3"
    )
    for nn in "${@}"; do
        parseTrap $(trap -p "${nn}")
    done
}

PS4='LINE: $((LASTNO=$LINENO)) : '; set -x
tic
trap 'toc "${LASTNO}" "${BASH_COMMAND}" "${LINENO}"; '"$(getCurTrap DEBUG)" DEBUG
trap 'trap - DEBUG; fExit >&3; '"$(getCurTrap EXIT)" EXIT INT TERM HUP QUIT


echo 'starting loop test'

for kk in $(sleep 1; seq 1 10); do echo hi
sleep 0.5s
echo bye; 
echo "$(sleep 0.2s; echo 'bye bye bye')"
done

echo 'finished loop test'
) 2>/dev/null
} 3>&2
