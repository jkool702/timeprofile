gg() {
(
local -a tDiffA tCmdA
local tDiffOut
local -x tic toc
tic() { t0=${EPOCHREALTIME}; }
toc() { t1=${EPOCHREALTIME}; tDiff0=$(( ${t1%.*} - ${t0%.*} )); tDiff1=$(( ${t1#*.} - ${t0#*.} )); (( ${tDiff1} < 0 )) && { ((tDiff0--)); tDiff1=$(( ${tDiff1} + 1000000 )); }; tDiffNew0=$(( ${tDiffA[$1]%.*} + ${tDiff0} )); [[ -n ${tDiffA[$1]} ]] || tDiffA[$1]=0.0; tDiffNew1=$(( ${tDiffA[$1]#*.} + ${tDiff1} )); (( ${tDiffNew1} >= 1000000 )) && { ((tDiffNew0++)); tDiffNew1=$(( ${tDiffNew1} - 1000000 )); }; tDiffA[$1]="${tDiffNew0}.${tDiffNew1}"; tCmdA[$1]="$2"; t0=${EPOCHREALTIME}; }
PS4='^MDEBUG: $((LASTNO=$LINENO)) :'; set -x
tic
trap 'toc ${LASTNO} "$BASH_COMMAND"' DEBUG;
trap 'trap - DEBUG; tDiffOut="$(declare -p tDiffA)"; tDiffOut="${tDiffOut//'"'"'declare -a tDiffA=('"'"'/}"; tDiffOut="${tDiffOut%)}"; paste <(echo "${tDiffOut// /$'"'"'\n'"'"'}") <(printf '"'"'(%s)\n'"'"' '"''"' "${tCmdA[@]}") >&3' EXIT INT TERM HUP QUIT
echo hi
sleep 2
echo bye
) 2>/dev/null
} 3>&2
