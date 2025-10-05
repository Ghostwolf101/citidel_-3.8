#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/citadel_onboard"
BIN="$ROOT/bin"
MODEL="${MODEL:-llama3-8b-safe}"
QUERY="${*:?Usage: rag_query.sh \"your question\"}"

"$BIN/context_builder.py" --query "$QUERY" --out /tmp/citadel_ctx.txt --meta /tmp/citadel_ctx.meta.json

PROMPT=$(cat /tmp/citadel_ctx.txt)

read -r -d '' FINAL <<'EOT' || true
You must answer using ONLY the context chunks below. Do not invent sources.
Cite the chunk_id(s) you used in brackets like [chunk:ID].
If the answer is not in the context, say: Not in archive.
EOT

FINAL="$FINAL
### CONTEXT START
$PROMPT
### CONTEXT END

### QUESTION
$QUERY
"

ollama run "$MODEL" "$FINAL"
