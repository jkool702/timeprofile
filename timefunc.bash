timefunc() {
(
local -ai tDiffA0 tDiffA1
local -a tCmdA fSrc
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

    [[ -n ${PREV_LINENO} ]] && {
        [[ -n ${tDiffA0[${PREV_LINENO}]} ]] || tDiffA0[${PREV_LINENO}]=0
        [[ -n ${tDiffA1[${PREV_LINENO}]} ]] || tDiffA1[${PREV_LINENO}]=0
        tDiffA0[${PREV_LINENO}]+=$(( ${t1%.*} - ${t0%.*} ))
        tDiffA1[${PREV_LINENO}]+=$(( ${t1##*.*(0)} - ${t0##*.*(0)} ))
    }
    [[ -n ${PREV_CMD} ]] && tCmdA[${PREV_LINENO}]+=$'\n'"${PREV_CMD}" 
    PREV_CMD="${2}"
    PREV_LINENO="${1}"
    t0=${EPOCHREALTIME}

}
fExit() {
    local -i kk
    local -ia kkAll
    kkAll=(${!tDiffA1[@]})
    for kk in ${!tDiffA1[@]}; do
        (( $kk == 1 )) && continue
        while (( ${tDiffA1[$kk]} < 0 )); do
            ((tDiffA0[$kk]--))
            tDiffA1[$kk]=$(( ${tDiffA1[$kk]} + 1000000 ))
        done
        while (( ${tDiffA1[$kk]} >= 1000000 )); do
            ((tDiffA0[$kk]++))
            tDiffA1[$kk]=$(( ${tDiffA1[$kk]} - 1000000 ))
        done
        if [[ -z $(echo "${tCmdA[$kk]}" | grep -v ':' | grep -E '.+') ]]; then
            tDiffA0[${kkAll[$kk]}]+=${tDiffA0[$kk]}
            tDiffA1[${kkAll[$kk]}]+=${tDiffA1[$kk]}
            continue
        fi
        tCmdA[$kk]="$(echo "${tCmdA[$kk]}" | sort | uniq -c | tail -n +2 | sed -E s/'^[ \t]*([0-9]+) '/'(\1x) '/)"
        
        printf '%d: %d.%06d sec \t{ %s }\n' "${kk}" "${tDiffA0[$kk]}" "${tDiffA1[$kk]}" "$(IFS=$'\n'; printf '%s;  ' ${tCmdA[$kk]})"
    done
}
getCurTrap() {
    local nn
    parseTrap() (
        echo "${3}"
    )
    for nn in "${@}"; do
        parseTrap $(trap -p "${nn}")
    done
}

#PS4='LINE: $((LASTNO=$LINENO)) : '; set -x

if [[ ${1,,} =~ ^-+s((ource)|(rc))?$ ]]; then
    [[ -f "${2}" ]] && source "${2}" || printf '\nWARNING: SPECIFIED SOURCE LOCATION (%s) NOT FOUND OR UN-SOURCABLE. IGNORING SOURCING THIS.\n\n' "${2}" >&2
    shift 2
elif  [[ ${1,,} =~ ^-+s((ource)|(rc))?=.+$ ]]; then
    [[ -f "${1#*=}" ]] && source "${1#*=}" || printf '\nWARNING: SPECIFIED SOURCE LOCATION (%s) NOT FOUND OR UN-SOURCABLE. IGNORING SOURCING THIS.\n\n' "${1#*=}" >&2
    shift 1
fi

declare -F "${1}" || { printf '\nERROR: SPECIFIED FUNCTION (%s) NOT SOURCED. PLEASE SOURCE IT AND RE-RUN.\n\n' "${1}" >&2; return 1; }

mapfile -t fSrc < <(declare -f "${1}" | sed -E s/'^((.*;)?[ \t]*)?((for)|(while)|(until)|(if)|(elif))(([ \t;])|$)'/'\1 :; \3 '/g)
source <(printf '%s\n' "${fSrc[@]:0:2}" ':' "${fSrc[@]:2}")

tic
trap 'trap - DEBUG; fExit >&2; '"$(getCurTrap EXIT)" EXIT INT TERM HUP QUIT
trap 'toc "${LINENO}" "${BASH_COMMAND}"; '"$(getCurTrap DEBUG)" DEBUG

"${@}"

) 
} 
