#!/bin/zsh
# Usage: preview_runs.sh <runs> <utterance> [<utterance2> ...]
# Runs N fresh preview conversations against the active RamBot in rambot-new and prints,
# per turn, the subagent, the actions executed, and the start of the reply (from the trace).
# Each conversation writes agent log records, so keep N small (storage is 5 MB).
source ~/.nvm/nvm.sh && nvm use 22 >/dev/null
export SF_DISABLE_TELEMETRY=true
cd "$(dirname "$0")/.."
N=$1; shift
for r in $(seq 1 $N); do
  SID=$(sf agent preview start -n RamBot -o rambot-new --json | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>console.log(JSON.parse(d).result.sessionId))')
  for u in "$@"; do sf agent preview send --session-id "$SID" -n RamBot -u "$u" -o rambot-new --json >/dev/null 2>&1; done
  sf agent preview end --session-id "$SID" -n RamBot -o rambot-new --json >/dev/null 2>&1
  echo "--- run $r"
  sf agent trace read -s "$SID" --json 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{for(const t of JSON.parse(d).result.turns){console.log("  ["+t.topic+"] actions="+JSON.stringify(t.actionsExecuted)+" | "+String(t.agentResponse).slice(0,150))}})'
done
