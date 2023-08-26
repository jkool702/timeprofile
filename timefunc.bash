timefunc() {
## Generates a line-by-line execution time profile for a bash function with very minimal overhead
# The 'time profile' is printed to stderr and includes (for each line): 
# total cumulative execution time, line number, command run, and number of times the command was run
#
# NOTE: Bash 5+ is required due to the use of the ${EPOCHREALTIME} builtin variable.
#
# # # # # USAGE # # # # #
# func() { ... }; timefunc func func_args
# timefunc (-s|--src|--source) <src> func func_args
# timefunc (-s|--src|--source)=<src> func func_args
# { ... } | timefunc [(-s|--src|--source) <src>] func funcArgs
#
# # # # # OPTIONS # # # # #
# The bash fuction being profiled may either be sourced prior to running `timefunc`, or 
# it can be sourced by specifying its location (which will be sourced) as timefunc's 1st option via any of:
#    -s <src> ; --src <src> ; --src=<src> ; --source <src>; --source=<src>
#
# NOTE: you can source non-file-paths by setting <src> as a single-quoted '<( ... )' command. example:
#    timefunc -s '<(curl '"'"'https://raw.githubusercontent.com/jkool702/timeprofile/main/timefunc.bash'"'"')'
#
# IFF timefunc's STDIN is a pipe ({ ... } | timefunc <...>), it will be passed to func's STDIN when it is called
#
################################################################################################################

(
local -ai tDiffA0 tDiffA1
local -a tCmdA fSrc
local -i tFinal0 tFinal1
local t0 tStart tStop PREV_CMD PREV_LINENO srcPath tStart tStop tFinal0 tFinal1

shopt -s extglob
set -T

tic() {
    ## start the timer
    t0=${EPOCHREALTIME}; 
    tStart="${t0}"
}

toc() { 
    ## record the command run and the time taken by command, then restart timer
    # save/update at array element array[$LINENO]
    # note: the time recorded this iteration is for the previous iteration's command
    
    # dont include commands from timefunc
    [[ ${#BASH_SOURCE[@]} == 1 ]] && return
    
    # get stop time
    local t1 
    t1=${EPOCHREALTIME}; 

    [[ -n ${PREV_LINENO} ]] && {
        # add time taken to count. add seconds and microseconds seperately.
        [[ -n ${tDiffA0[${PREV_LINENO}]} ]] || tDiffA0[${PREV_LINENO}]=0
        [[ -n ${tDiffA1[${PREV_LINENO}]} ]] || tDiffA1[${PREV_LINENO}]=0
        tDiffA0[${PREV_LINENO}]+=$(( ${t1%.*} - ${t0%.*} ))
        tDiffA1[${PREV_LINENO}]+=$(( ${t1##*.*(0)} - ${t0##*.*(0)} ))
    }
    
    # add command run to record
    [[ -n ${PREV_CMD} ]] && tCmdA[${PREV_LINENO}]+=$'\n'"${PREV_CMD}" 
    
    # setup for next command
    PREV_CMD="${2}"
    PREV_LINENO="${1}"
    t0=${EPOCHREALTIME}

}

fExit() {
    ## actually generate the time profile
    
    local -i kk
    local -ia kkAll
    kkAll=(${!tDiffA1[@]})
    
    tStop="${EPOCHREALTIME}"
    
    for kk in ${!tDiffA1[@]}; do
    
        [[ $kk == 1 ]] && continue
    
        # make sure cumulative microsecond count is between 0 and 0.999999 seconds
        while (( ${tDiffA1[$kk]} < 0 )); do
            ((tDiffA0[$kk]--))
            tDiffA1[$kk]=$(( ${tDiffA1[$kk]} + 1000000 ))
        done
        while (( ${tDiffA1[$kk]} >= 1000000 )); do
            ((tDiffA0[$kk]++))
            tDiffA1[$kk]=$(( ${tDiffA1[$kk]} - 1000000 ))
        done
        
        # place time from dummy `:` commands 
        if [[ -z $(echo "${tCmdA[$kk]}" | grep -v ':' | grep -E '.+') ]]; then
            tDiffA0[${kkAll[$kk]}]+=${tDiffA0[$kk]}
            tDiffA1[${kkAll[$kk]}]+=${tDiffA1[$kk]}
            continue
        fi
        
        # reduce command list into '(Nx) command' format
        tCmdA[$kk]="$(echo "${tCmdA[$kk]}" | sort | uniq -c | tail -n +2 | sed -E s/'^[ \t]*([0-9]+) '/'(\1x) '/)"
        
        # print line for final generated time profile
        printf '%d:\t%d.%06d sec \t{  %s}\n' "${kk}" "${tDiffA0[$kk]}" "${tDiffA1[$kk]}" "$(IFS=$'\n'; printf '%s;  ' ${tCmdA[$kk]})"
    done
    
    # print total execution time
    tFinal0=$(( ${tStop%.*} - ${tStart%.*} )) 
    tFinal1=$(( ${tStop##*.*(0)} - ${tStart##*.*(0)} ))
    (( ${tFinal1} < 0 )) && { ((tFinal0--)); tFinal1=$(( ${tFinal1} + 1000000 )); }
    printf '\nTOTAL TIME TAKEN: %d.%06d seconds\n\n' ${tFinal0} ${tFinal1}
}

# if 1st timefunc option specifies what to source to get the function, parse it and source it
if [[ ${1,,} =~ ^-+s((ource)|(rc))?$ ]]; then
    srcPath="${2}"
    shift 2
elif  [[ ${1,,} =~ ^-+s((ource)|(rc))?=.+$ ]]; then
    srcPath="${1#*=}"
    shift 1
fi
if [[ -n "${srcPath}" ]]; then
    if [[ -f "${srcPath}" ]]; then
        source "${srcPath}"
    elif [[ "${srcPath}" == '<('* ]]; then
        source <(cat<<EOF
source ${srcPath}
EOF
)    
    else
        printf '\nWARNING: SPECIFIED SOURCE (%s) NOT FOUND OR UN-SOURCABLE. IT WILL NOT BE SOURCED.\n\n' "${srcPath}" >&2
    fi
fi

# check that the function is sourced
declare -F "${1}" || { printf '\nERROR: SPECIFIED FUNCTION (%s) NOT SOURCED. PLEASE SOURCE IT AND RE-RUN.\n\n' "${1}" >&2; return 1; }

# add in a few dummy commands (` :; `) a few places to ensure the DEBUG trap captures the command
mapfile -t fSrc < <(declare -f "${1}" | sed -E s/'^((.*;)?[ \t]*)?((for)|(while)|(until)|(if)|(elif))(([ \t;])|$)'/'\1 :; \3 '/g)
source <(printf '%s\n' "${fSrc[@]:0:2}" ':;' "${fSrc[@]:2}")

# set traps and start timer
trap 'trap - DEBUG; fExit >&2' EXIT INT TERM HUP QUIT
tic

# run function (passing it STDIN if needed)
if [[ -t 0 ]]; then
    trap 'toc "${LINENO}" "${BASH_COMMAND}"' DEBUG
    "${@}"
else
    trap 'toc "${LINENO}" "${BASH_COMMAND}"' DEBUG
    "${@}" <&0
fi
trap - DEBUG
tStop="${EPOCHREALTIME}"

) 
} 
