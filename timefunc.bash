timefunc() {
## Generates a line-by-line execution time profile for a bash function / script with very minimal overhead
# The 'time profile' is printed to stderr and includes (for each line): 
# total cumulative execution time, line number, command run, and number of times the command was run
#
# NOTE: Bash 5+ is required due to the use of the ${EPOCHREALTIME} builtin variable.
#       Several common GNU coreutils are also required (cat, sed, grep, sort, cut, head, tail, ...)
#
#
# # # # # USAGE # # # # #
#
# source /path/to/timefunc.bash
# source <(curl 'https://raw.githubusercontent.com/jkool702/timeprofile/main/timefunc.bash')
#
# func() { ... }; timefunc func [func_args]
# timefunc (-s|--src|--source) <src> func [func_args]
# timefunc (-s|--src|--source)=<src> func [func_args]
# { ... } | timefunc [(-s|--src|--source) <src>] func [func_args]
# timefunc (-S|--script) <scriptPath> [script_args]
# timefunc (-S|--script)=<scriptPath> [script_args]
# { ... } | timefunc (-S|--script) <scriptPath> [script_args]
#
#
# # # # # OPTIONS # # # # #
#
# -s | --src | --source : function source locstion to be sourced (not needed if function is already sourced)
# -S | --script         : script source location (the script will be wrapped into a dummy function and sourced)
#
# NOTE: timefunc flags must be given before other arguments
# NOTE: anything passed to timefunc's STDIN will be redirected to the STDIN of the function being time-profiled
#
#
# # # # # EXTRA INFORMATION / DETAILS / NOTES # # # # #
#
# The bash function being profiled may either be sourced prior to running `timefunc`, or 
# it can be sourced by specifying its location (which will be sourced) as timefunc's 1st option(s) via any of:
#    -s <src> ; --src <src> ; --src=<src> ; --source <src>; --source=<src>
#
# NOTE: you can source non-file-paths by setting <src> as a single-quoted '<( ... )' command. example:
#    timefunc -s '<(curl '"'"'https://raw.githubusercontent.com/jkool702/timeprofile/main/timefunc.bash'"'"')'
#
# Though originally intended for just functions, timefunc was extended to generate time profiles for bash scripts
# This is done by wrapping the script inside of a dummy function. To use, set timefunc's 1st option(s) to any of:
#    -S <scriptPath> ; --script <scriptPath> ; --script=<scriptPath>
#
# IFF timefunc's STDIN is a pipe ({ ... } | timefunc <...>), it will be passed to func's STDIN when it is called
#
#
#################################################################################################################

(
# make vars local
local -ai tDiffA0 tDiffA1
local -a tCmdA fSrcA subshellLines timesCur
local t0 t1 t11 tStart tStop srcPath scriptFlag last_subshell min_subshell PREV_CMD PREV_LINENO tFinal0 tFinal1 tCmd subshellData dataCur fSrc fSrc0 fSrc1 fFlag
local -i tFinal0 tFinal1 tDiff0 tDiff1

# set options. -T is needed to propagate the traps into the functions and its subshells. extglob is needed by the cumulative time tracking code.
shopt -s extglob
set -T

tic() {
    ## start the timer
    tDiffA0=()
    tDiffA1=()
    tCmdA=()
    t0=${EPOCHREALTIME}; 
    tStart="${t0}"
}

toc() { 
    ## record the command run and the time taken by command, then restart timer
    # save/update at array element array[$LINENO]
    # note: the time recorded this iteration is for the previous iteration's command
    
    # set exit trap from debug trap so that `set -T` propagates it too
    [[ "${last_subshell}" == "${3}" ]] || { tic; last_subshell="${3}"; trap 'trap - DEBUG; fExit >&2; : timefunc_exitTrapSet' EXIT INT TERM HUP QUIT; }
    
    # dont include commands from timefunc
    [[ ${#BASH_SOURCE[@]} == 1 ]] && return
    
    # get stop time
    local t1 
    t1=${EPOCHREALTIME}; 

    [[ -n ${PREV_LINENO} ]] && {
        # add time taken to count. add seconds and microseconds separately. Microseconbds may not stay between 0-999999, but will get fixed later.
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
    kkAll=("${!tDiffA1[@]}")
    
    tStop="${EPOCHREALTIME}"
    
    for kk in "${!tDiffA1[@]}"; do
    
        #[[ $kk == 1 ]] && continue
    
        # make sure the cumulative microsecond count is between 0 and 0.999999 seconds
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
        
        if [[ ${last_subshell} == ${min_subshell} ]]; then
            # save lines from main shell in final output format
        
            # reduce command list into '(Nx) command' format
            tCmdA[$kk]="$(echo "${tCmdA[$kk]}" | sort | uniq -c | tail -n +2 | sed -E s/'^[ \t]*([0-9]+) '/'(\1x) '/)"
        
            # print line for final generated time profile
            printf '%d.%d:\t%d.%06d sec \t{ %s}\n' "${last_subshell}" "${kk}" "${tDiffA0[$kk]}" "${tDiffA1[$kk]}" "$(IFS=$'\n'; printf '%s;  ' ${tCmdA[$kk]})" >>./timeprofile."${fName}"
            
        else
            # save lines from subshells as raw data. Will be combined+parsed into final format later
            
            # print commands seperated by spacer \034
            tCmdA[$kk]="${tCmdA[$kk]//$'\n'/$'\034'}"
            
            # save times and commands to file
            printf '%d.%d\t%d.%06d\t%s\n' "${last_subshell}" "${kk}" "${tDiffA0[$kk]}" "${tDiffA1[$kk]}" "${tCmdA[$kk]})" >>./timeprofile."${fName}".subshells
        fi
    done
    
    # print total execution time
    [[ ${last_subshell} == ${min_subshell} ]] && {

        tFinal0=$(( ${tStop%.*} - ${tStart%.*} )) 
        tFinal1=$(( ${tStop##*.*(0)} - ${tStart##*.*(0)} ))
        (( ${tFinal1} < 0 )) && { ((tFinal0--)); tFinal1=$(( ${tFinal1} + 1000000 )); }
        printf '\nTOTAL TIME TAKEN: %d.%06d seconds\n\n' ${tFinal0} ${tFinal1}  >>./timeprofile."${fName}"
           
       [[ -f ./timeprofile."${fName}".subshells ]] && {
        
            printf '\nSUBSHELL COMMANDS\n\n' >>./timeprofile."${fName}"
        
            subshellData="$(cat ./timeprofile."${fName}".@([2-9]) ./timeprofile."${fName}".subshells 2>/dev/null | sort -V -k1)";
            mapfile -t subshellLines < <(echo "${subshellData}" | cut -f 1 | sort -u | sort -V)
            for kk in "${!subshellLines[@]}"; do
                dataCur="$(echo "${subshellData}" | grep -E '^'"${subshellLines[$kk]}")"
                mapfile -t timesCur < <(echo "${dataCur}" | cut -f 2)
                
                tDiff0=0
                tDiff1=0
                for t11 in "${timesCur[@]}"; do
                    tDiff0+=${t11%.*}
                    tDiff1+=${t11##*.*([0])}
                done
                while (( ${tDiff1} > 999999 )); do
                    ((tDiff0++))
                    tDiff1=$(( ${tDiff1} -  1000000 ))
                done
                
                tCmd="$(echo "${dataCur}" | cut -f 3- | tr $'\034' $'\n' | sort | uniq -c | tail -n +2 | sed -E s/'^[ \t]*([0-9]+) '/'(\1x) '/)"
                
                # print line for final generated time profile
                printf '%s:\t%d.%06d sec \t{ %s}\n' "${subshellLines[$kk]}" "${tDiff0}" "${tDiff1}" "$(IFS=$'\n'; printf '%s;  ' ${tCmd})" >>./timeprofile."${fName}"
            
            done
        }
        

            
        rm ./timeprofile."${fName}".subshells
        cat ./timeprofile."${fName}"  >&2
        printf '\ntime profile for %s has been saved to %s\n\n' "${fName}" "$(realpath ./timeprofile."${fName}")" >&2
    }
}

# if 1st timefunc option(s) specify what to source to get the function/script, parse it and source it
# if time profiling a script then wrap it in a dunny function (tfunc) and source that
scriptFlag=false
if [[ ${1} =~ ^-+((S)|(script))?$ ]]; then
    srcPath="${2}"
    scriptFlag=true
    shift 2
elif  [[ ${1} =~ ^-+((S)|(script))=.+$ ]]; then
    srcPath="${1#*=}"
    scriptFlag=true
    shift 1
elif [[ ${1} =~ ^-+s((ource)|(rc))?$ ]]; then
    srcPath="${2}"
    shift 2
elif  [[ ${1} =~ ^-+s((ource)|(rc))=.+$ ]]; then
    srcPath="${1#*=}"
    shift 1
fi
if [[ -n "${srcPath}" ]]; then
    [[ -f "${srcPath}" ]] && { cat "${srcPath}" | head -n 1 | grep -E '^#!.*bash.*$' || printf '\n%s\n\n' 'WARNING: specified source does not explicitly have a shebang indicating it is bash code.'$'\n''         Time profile generation is unlikely to succeed on code written in other languages.'; }
    if ${scriptFlag}; then
        # time profiling a script
        
        # get script source
        if [[ -f "${srcPath}" ]]; then
            fSrc="$(cat "${srcPath}")"
        elif [[ "${srcPath}" == '<('*')' ]]; then
            fSrc="$(source <(printf 'cat %s' "${srcPath}"))"
        else
            printf '\nERROR: SPECIFIED SCRIPT SOURCE (%s) NOT FOUND OR UN-SOURCABLE. IT CANNOT NOT BE SOURCED, AND THUS CANNOT BE TIME-PROFILED.\n\n' "${srcPath}" >&2
            return 1            
        fi
        
        # wrap it in a dummy function (tfunc). preserve shebang if present.
        if [[ "${fSrc%%$'\n'*}" == '#!'* ]]; then
                source <(cat<<EOF
${fSrc%%$'\n'*}
tfunc() {
${fSrc#*$'\n'}
}
EOF
)
        else
                source <(cat<<EOF
#!/usr/bin/env bash
tfunc() {
${fSrc}
}
EOF
)
        fi
        
        # remove script path from calling command (replaced with `tfunc`)
        [[ "${1}" == "${srcPath}" ]] && shift 1
        
    elif [[ -f "${srcPath}" ]]; then
        # using function, source from path at $srcPath
        source "${srcPath}"
    elif [[ "${srcPath}" == '<('*')' ]]; then
        # using function, source from <(...) command given in $srcPath
        source <(cat<<EOF
source ${srcPath}
EOF
)    
    else
        printf '\nWARNING: SPECIFIED SOURCE (%s) NOT FOUND OR UN-SOURCABLE. IT WILL NOT BE SOURCED.\n\n' "${srcPath}" >&2
    fi
fi
${scriptFlag} && fName='tfunc' || fName="${1}"

# check that the function is sourced
declare -F "${fName}" || { printf '\nERROR: SPECIFIED FUNCTION (%s) NOT SOURCED. PLEASE SOURCE IT AND RE-RUN.\n\n' "${1}" >&2; return 1; }

# add in a few dummy commands (` :; `) a few places (e,.g. just before loops) to ensure the DEBUG trap captures the command properly
mapfile -t fSrcA < <(declare -f "${fName}" | sed -E s/'^((.*;)?[ \t]*)?((for)|(while)|(until)|(\())(([ \t;])|$)'/'\1 :; \3 '/g)
source <(printf '%s\n' "${fSrcA[@]:0:2}" ':;' "${fSrcA[@]:2}")

# pull out any defined functions and source them seperately, and
# dont let defining DEBUG/EXIT traps in the function overwrite those needeed by timeprofile
fFlag=false; fSrc0=''; fSrc1='';
{
    while read -r; do
        echo "$REPLY" | grep -qE '^[ \t]*function [^ ]+ ()' && {
            fFlag=true
            endStr="$(echo "$REPLY" | sed -E s/'^([ \t]*).*$'/'\1\};'/)"
        }
        ${fFlag} && fSrc1+="${REPLY}"$'\n' || fSrc0+="${REPLY}"$'\n'
        [[ "${REPLY}" == "${endStr}" ]] && fFlag=false
    done
} < <(declare -f "${fName}" | sed -E s/'trap (.*[^\-].*) DEBUG'/'trap \1'"'"'; toc "${LINENO}" "${BASH_COMMAND}" "${BASH_SUBSHELL}"'"'"' DEBUG'/ | sed -E s/'trap (.*[^\-].*) EXIT'/'trap \1'"'"'; trap - DEBUG; fExit >&2; : timefunc_exitTrapSet'"'"' EXIT'/)
[[ -n "${fSrc1}" ]] && source <(echo "${fSrc1}")
source <(echo "${fSrc0}")

# if a time profileists on disk where this one will be saved, move it to <path>.old
[[ -f ./timeprofile."${fName}".subshells ]] && { cat ./timeprofile."${fName}".subshells >> ./timeprofile."${fName}".subshells.old; rm ./timeprofile."${fName}".subshells; }
[[ -f ./timeprofile."${fName}" ]] && { cat ./timeprofile."${fName}" >> ./timeprofile."${fName}".old; rm ./timeprofile."${fName}"; }

# start timer
tic

# set traps and run function (passing it STDIN if needed)
if [[ -t 0 ]]; then
    min_subshell=1
    trap 'toc "${LINENO}" "${BASH_COMMAND}" "${BASH_SUBSHELL}"' DEBUG
    ${scriptFlag} && tfunc "${@}" || "${@}"
else
    min_subshell=2
    trap 'toc "${LINENO}" "${BASH_COMMAND}" "${BASH_SUBSHELL}"' DEBUG
    ${scriptFlag} && tfunc "${@}" <&0 || "${@}" <&0
fi
trap - DEBUG

) 
} 
