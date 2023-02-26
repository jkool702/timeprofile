# timeprofile
A tool for measuring the execution time of all commands called by a shell script or shell function very efficiently using a DEBUG trap and a bash coproc.

USAGE: run `setup.bash` to save the required script to `/usr/local/bin/addTimeProfile`. To actually utalize this script and generate a timeprofile, add the following line to the top of the script (just after shebang) / function (just after function declarion) that you want to profile:

    [[ -n ${timeProfileFlag} ]] && ${timeProfileFlag} && source /usr/local/bin/addTimeProfile

Then, to generate a profile, run the function/script using:

    timeProfileFlag=true <funcName>

The timeprofile will be savedin your current directory under the name `.timeprofile.<funcName>`. If this file exists the old version will first be appended to `.timeprofile.<funcName>.old`.

NOTE: the timeprofile is generated *much* more efficiently in bash 5+ due to the availability of `$EPOCHREALTIME`. Most bash scripts will run at >80\% of the speed they run without being profiled. Extreamly optimized shell scripts that deal with many very fast iterations may slow down by a factor of 2-3x in a worst-case scenario. 

The timeprofile can still be generated using bash 4 (using `$(date +'%s.%N')`), but will cause significant slowing down of the function being profiled. Bash 3 and older are not supported due to not having coprocs. The `timeprofile/old/bash` script *might* work for bash 3 and older, but it is not supported noir tested.