#!/bin/bash

timeprofile() {
	## PROVIDES A BREAKDOWN OF THE EXECUTION TIME OF ALL THE SUB-COMMANDS CALLED BY THE SPECIFIED FUNCTION/SCRIPT
	#
	# USAGE: timeprofile funcToBeProfiled [funcArgs]
	#
	# NOTE: the "funcToBeProfiled" must be a shell script / shell function containing ASCII text in order to have its sub-sommands timed
	#       sub-command execution time measurement is not supported if "funcToBeProfiled" is anything else (e.g., a compiled binary)
	
	# declare local variables
	
    local fName
    local fDef
    local fDef0
    local strAddTrapExit
    local strAddTrapDebug
    local fTmpDirPath
    local fScriptTmpPath
    local fTimeProfileTmpPath
    local fEpochPath
    local fShebang
    local funcFlag
    
    
	# get source and determine if it is a shell script or a shell function

    fName="${1}"
    shift 1

    if declare -F "${fName}"; then
        fDef0="$(declare -f "${fName}")"
        fDef="${fDef0#*'{'}"
        fDef="${fDef%'}'*}"
        funcFlag=true
    elif { [[ -f "$(which "${fName}")" ]] && file "$(which "${fName}")" || echo ''; } | grep -q -F -f <(printf '%s\n' 'shell script' 'ASCII text'); then
       fDef="$(cat "$(which "${fName}")")"
       fDef0="${fDef}"
       funcFlag=false
    else
        echo -e "\nERROR: could not find bash source code for ${fName} \nWould you like to run the code without timing its sub-commands?\n"
        PS3='would you like to continue?'
        select response in YES NO
        do
            [[ "${RESPONSE}" == 'YES' ]] && time "${fName}" "${@}"
            return
            break
        done
    fi
    
	# setup tmp dir to (temporairly) hold the generated modded script and time profile
	
    mkdir -p /tmp/.timeprofile
	
    fTmpDirPath="$(mktemp -p '/tmp/.timeprofile/' -t "${fName##*/}"'.tmp-XXXXXX' -d)"
    fScriptTmpPath="${fTmpDirPath}/${fName##*/}.tmpfunc-${fTmpDirPath##*-}"
    fTimeProfileTmpPath="${fTmpDirPath}/${fName##*/}.timeprofile-${fTmpDirPath##*-}"
    fEpochPath="${fTmpDirPath}/${fName##*/}.epoch-${fTmpDirPath##*-}"
	
	# Start the modified function by defining functions for trap <...> DEBUG/EXIT
	# These record the current total elapsed time, which in turn allows figuring out the previous command's execution time, and the current commend is recorded 
	# DEBUG/EXIT traps that call these are placed at the top of the moddified script (after these function definitions) and at the top of any additional functions defined in the original function/script.
	# NOTE: if the original command is a function, the "top of the script" traps are inside the top-most 'funcname() {' definition
 
	fShebang="$(echo "${fDef0}" | grep -E '^#!' | head -n 1)"
    [[ -z ${fShebang} ]] && fShebang='#!/bin/bash'
	
    cat << EOF_TIMEPROFILE > "${fScriptTmpPath}"
	${fShebang}
    [[ -f "${fTimeProfileTmpPath}" ]] && rm -f "${fTimeProfileTmpPath}"
    
timeprofile_debugtrap() {
    [[ -f "${fTimeProfileTmpPath}" ]] && printf 'COMMAND ELAPSED TIME: %s SECONDS \nTOTAL ELAPSED TIME:   %s SECONDS\n' "\$(bc<<<'('"\${EPOCHREALTIME}"'-'"\$(tail -n 1 "${fEpochPath}")"')')" "\$(bc<<<'('"\${EPOCHREALTIME}"'-'"\$(head -n 1 "${fEpochPath}")"')')" >> "${fTimeProfileTmpPath}" || touch "${fTimeProfileTmpPath}"
    printf '\nCOMMAND: %s \n' "\${*}" >> "${fTimeProfileTmpPath}"
    echo "\${EPOCHREALTIME}" >> "${fEpochPath}"
}

timeprofile_exittrap() {
    cat "${fTimeProfileTmpPath}" | grep -E '^.*[^ \t]+.*$' | tail -n 1 | grep -q-E '^COMMAND' && printf ' TOTAL ELAPSED TIME:  %s SECONDS \nCOMMAND ELAPSED TIME: %s SECONDS\n' "\$(bc<<<'('"\${EPOCHREALTIME}"'-'"\$(tail -n 1 "${fEpochPath}")"')')" "\$(bc<<<'('"\${EPOCHREALTIME}"'-'"\$(head -n 1 "${fEpochPath}")"')')" >> "${fTimeProfileTmpPath}"
    trap - DEBUG
    printf '\n\nTHE MODIFIED FUNCTION GENERATED AND USED BY TIMEPROFILE IS AT: \n%s\n\n' "${fScriptTmpPath}" >> "${fTimeProfileTmpPath}"
    cat "${fTimeProfileTmpPath}" | tee -a "$(pwd)/.timeprofile.${fName##*/}"
    echo "\${EPOCHREALTIME}" >> "${fEpochPath}"
	trap -  EXIT ERR HUP INT TERM
}

EOF_TIMEPROFILE

	# define strings to add to the midded scriot to setup traps

    strAddTrapExit='trap '"'"'timeprofile_exittrap'"'"' EXIT ERR HUP INT TERM'
    strAddTrapDebug='trap '"'"'timeprofile_debugtrap "${BASH_COMMAND}"'"'"' DEBUG'

	#  generate the rest of the modded script. This entails:
	# 1. Add traps at top under the timeprofile_{exit,debug}trap function definitions
	# 2. Add the original function/script body modified with a "sed" command to add strAddTrap{exit,debug} to the start of any functions defined by the original function/script
	# 3. Add some calls to the end of the function/script to clean things up

    cat << EOF_TIMEPROFILE >> "${fScriptTmpPath}"

${strAddTrapExit}

$(${funcFlag} && { echo "${fDef0%%'{'*}"'{'; echo; }; )

${strAddTrapDebug}

$(echo "${fDef}" | sed -zE s/'(^%|\n)([ \t]*[^ \t\n]+ ?\(\)[ \t\n]*\{)'/'\n\2\n'"${strAddTrapExit}"'\n'"${strAddTrapDebug}"'\n'/g)

timeprofile_exittrap

$(${funcFlag} && echo '}'"${fDef0##*'}'}")

EOF_TIMEPROFILE

	# run the requested command, replacing the original function/sscript with the newly-generated modified function/script 
    
    chmod +x "${fScriptTmpPath}"
	
    if ${funcFlag}; then
		# original is a declared function. 
		# source the modded function, run the modified function (passing the function inputs and (if given) standard input provided to timeprofile), then source the original function definition again

        source "${fScriptTmpPath}" 
        [ -t 1 ] && "${fName}" "${@}" || cat | "${fName}" "${@}" 
        source <(echo "${fDef0}")
    else
		# original is a shell script. 
		# first, try running the modified script, passing the function/standard inputs given to timeprofile to it
		# if this fails, the original might actually be a shell function and not a shell script. Try sourcing it, and then either
		#    1. if a function with the same name is declared by sourcing it, re-run timeprofile. timeprofile will then initilly choose the "declared fucnction" path now that the function has actually been declared
		#    2. if no declared function of the same name appears after sourcing, re-run the modified script with the original one already sourced
		
        [ -t 1 ] && "${fScriptTmpPath}" "${@}" || cat | "${fScriptTmpPath}" "${@}"
		if (( $? > 0 )) ; then
			source "$(which "${fName}")"
			if declare -F "${fName}"; then
				timeprofile "${fName}" "${@}"
			else
				[ -t 1 ] && "${fScriptTmpPath}" "${@}" || cat | "${fScriptTmpPath}" "${@}" 
			fi
		fi
    fi
	
	# unset all traps
	trap - DEBUG EXIT ERR HUP INT TERM
}
