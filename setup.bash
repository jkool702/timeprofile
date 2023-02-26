#!/bin/bash

    
# setup
mkdir -p /usr/local/bin/
cat<<'EOF' > /usr/local/bin/addTimeProfile
#!/bin/bash
{
    # set filename to save time profile at. if it already exists append its contents to "old" copy.
    [[ -n ${FUNCNAME[1]} ]] && timeProfileFile=".timeprofile.${FUNCNAME[1]}" || timeProfileFile=".timeprofile.${BASH_SOURCE[1]##*/}"
    [[ -f "${timeProfileFile}" ]] && cat "${timeProfileFile}"  >> "${timeProfileFile}.old"
    
    (( $(bash --version | head -n 1 | grep -oE 'version [0-9]+' | cut -d ' ' -f 2) >= 5 )) && haveEpochFlag=true || haveEpochFlag=false
    
    # fork a coproc that will determine elapsed time
    # since the last command triggered the DEBUG trap
    # and print elapsed time + the command that was run
    { coproc pTime {
        # set initial values for "last" time/command
        ${haveEpochFlag} && { a="$EPOCHREALTIME"; d0=6; } || { a="$(date +'%s.%N')"; d0=9; }
        REPLY0='BEGIN FUNCTION'
        while true; do
            # read $BASH_COMMAND on stdin ("current" command) --> triggers getting "current" time --> get elapsed time
            read -r
            # get time difference between "last" and "current" time (in microseconds)
            ${haveEpochFlag} && b="$EPOCHREALTIME" || b="$(date +'%s.%N')"
            c=$(( ${b//./} -  ${a//./} ))
            # print elapsed time + last command
             d=$(( ${#c} - ${d0} ))
            (( $d > 0 )) && printf '%s seconds%s\n' "${c:0:${d}}.${c:${d}}" "${REPLY0}" >&4 || printf '0.%0.'${d0}'d seconds%s\n' "$c" "${REPLY0}" >&4
            # cycle "current" time/command to "last" time/command
            a=$b
            REPLY0="${REPLY}"
        done
        }
    # redirect to file. redirect to stderr instead by changing to `5>&2`, but warning: this may cause some scripts to not exit properly and get stuck in a loop.
    } 4>"${timeProfileFile}"
    
    # set DEBUG trap to send BASH_COMMAND to coproc       
    # set EXIT trap to clear debug trap. 
    # If another exit/debug trap already exists add these into it.
    for nn in EXIT HUP TERM QUIT DEBUG; do 
        curTrap="$(trap -p "$nn")"
        curTrap="${curTrap#*"'"}"
        curTrap="${curTrap%"'"*}"
        [[ -n "${curTrap}" ]] && trapNew="${curTrap}"'; ' || trapNew=''
        if [[ "$nn" == DEBUG ]]; then
            trapNew="$trapNew"'echo ": ${BASH_COMMAND}" >&${pTime[1]} || :'              
        else
            trapNew="$trapNew"'trap - DEBUG; echo "The generated line-by-line time profile is  located at '"${timeProfileFile}"'" >&2' 
        fi
        trap -- "$trapNew" "$nn"
    done        
}
EOF

printf '%s\n' '' 'TO GENERATE A TIME PROFILE FOR A FUNCTION/SCRIPT, ADD THE FOLLOWING LINE TO THE TOP OF THE FUNCTION/SCRIPT:' '' '    [[ -n ${timeProfileFlag} ]] && ${timeProfileFlag} && source /usr/local/bin/addTimeProfile' '' 'THEN, CALL THE FUNCTION/SCRIPT VIA:' '' '    timeProfileFlag=true <funcName>' ''
