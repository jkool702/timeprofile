#!/bin/bash

# timeprofile.new.sh
#
# Uses DEBUG and EXIT traps to efficiently generate a command-by-command time profile for a function/script
#
# this version of timeprofile is somewhat simplier but is more reliable and has less overhead
# it will record the time the command was ecexuted at, the line number, and the command and save it to <NAME>.timeprofile
# it will set an EXIT trap to convert the times in this file to time differences between the commands 
# (the conversion to time differences in the time profile will happen after everything else is finished running)
#
# REQUIRES: BASH 5+  (since it uses ${EPOCHREALTIME} and the ${VAR@Q} variable quoting operator)
#
# TO USE THIS: add 'source /path/to/timeprofile.new.sh' (replace with real path obviously) to the function/script you want to time profile
#
# NOTE: source timeprofile as close to the top of function/script as possible but UNDER any other DEBUG or EXIT trap definitions 
#       definitiions existing EXIT/DEBUG traps will be automatically added into the ones set by timeprofile. 
#       IF you define an EXIT or DEBUG AFTER you source timeprofile the ones set by timeprofile will be overwritten and it wont work.

timeprofile_genTimeDiff() {
    local -a timeProfileA
    local -a timeProfileAA
    local timeTmp
    local skipFlag
    local timeprofile_file1
    local timeprofile_file2

    case $# in
        0) [[ -n ${timeprofile_file} ]] && { timeprofile_file1="${timeprofile_file}"; timeprofile_file2="${timeprofile_file}"; } || return 1;;
        1)  timeprofile_file1="${1}"; timeprofile_file2="${1}";;
        *)  timeprofile_file1="${1}"; timeprofile_file2="${2}";;
    esac

    mapfile -t timeProfileA < "${timeprofile_file1}"
    timeProfileAA=("${timeProfileA[@]%%)*}")
    timeProfileAA+=(${EPOCHREALTIME})
    timeProfileAA=("${timeProfileAA[@]//[\(\.]}")
    
    skipFlag=true
    for kk in ${!timeProfileAA[@]}; do
        [[ -n ${timeProfileAA[$kk]} ]] || continue
        ${skipFlag} && { skipFlag=false; continue; } || timeTmp=$(printf '%07d' $(( ${timeProfileAA[$kk]} - ${timeProfileAA[$(( $kk - 1 ))]} )) )
        printf '(%s.%s): %s\n' ${timeTmp:0:-6} ${timeTmp: -6} "${timeProfileA[$(( $kk - 1 ))]#*): }"
    done > "${timeprofile_file2}"
}

timeprofile_setup () {
    local curTrapDebug
    local curTrapExit
    
    curTrapDebug="$(trap -p DEBUG)"
    curTrapDebug="${curTrapDebug#*"'"}"
    curTrapDebug="${curTrapDebug%"'"*}"
    [[ -n ${curTrapDebug} ]] && curTrapDebug="${curTrapDebug%;}; "

    curTrapExit="$(trap -p EXIT)"
    curTrapExit="${curTrapExit#*"'"}"
    curTrapExit="${curTrapExit%"'"*}"
    [[ -n ${curTrapExit} ]] && curTrapExit="${curTrapExit%;}; "

    [[ -n ${timeprofile_file} ]] || { "${FUNCNAME[1]}"[ -n ${FUNCNAME[1]} ]] && timeprofile_file="${FUNCNAME[1]}.timeprofile"; } || timeprofile_file="${BASH_SOURCE[1]}.timeprofile";
    [[ -n ${timeprofile_file} ]] || timeprofile_file="timeprofile.timeprofile";
    [[ -f "${timeprofile_file}" ]] && cat "${timeprofile_file}" >> "${timeprofile_file}.old" && echo '' > "${timeprofile_file}";

    trap "${curTrapExit}"'trap - DEBUG; timeprofile_genTimeDiff '"${timeprofile_file}" EXIT

    trap "${curTrapDebug}"'printf '"'"'(%s): %s -- %s\n'"'"' "${EPOCHREALTIME}" "${LINENO}" "${BASH_COMMAND@Q}" >> '"${timeprofile_file}" DEBUG
}

set -T

timeprofile_setup
