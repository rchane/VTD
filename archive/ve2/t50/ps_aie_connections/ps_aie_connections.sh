#!/usr/bin/env bash

set -euo pipefail

DEVMEM2=${DEVMEM2:-devmem2}
EXPECT=${EXPECT:-0xDEADBEEF}
ADDR_BASE=${ADDR_BASE:-0}
COL_LAST=${COL_LAST:-36}

strip() { local z=${1#0x}; echo "${z#0X}"; }
want=$(printf %08X $((16#$(strip "$EXPECT"))))
base=$((16#$(strip "$ADDR_BASE")))

command -v "$DEVMEM2" >/dev/null 2>&1 || {
	echo "error: $DEVMEM2 not found" >&2
	exit 1
}
((COL_LAST <= 36)) || {
	echo "error: COL_LAST must be 0..36" >&2
	exit 1
}

# First hex after "): " on Value line, else last 0x word in output
read_hex() {
	local v
	v=$(printf '%s\n' "$1" | grep -F 'Value at address' | tail -1 |
		sed -n 's/.*):[[:space:]]*0x\([0-9A-Fa-f]*\).*/\1/p')
	[[ -n "$v" ]] || v=$(printf '%s\n' "$1" | grep -oE '0x[0-9A-Fa-f]+' | tail -1 | sed 's/^0x//')
	printf '%s' "${v:-}"
}

for col in $(seq 0 "$COL_LAST"); do
	a=$((base + (col << 25) + (1 << 20)))
	h=$(printf '0x%08X' "$a")

	set +e
	wo=$("$DEVMEM2" "$h" w "$EXPECT" 2>&1)
	wr=$?
	set -e
	if ((wr != 0)); then
		printf '[col %2d] %s WRITE_FAIL write_rc=%s\n' "$col" "$h" "$wr"
		[[ -n "$wo" ]] && sed 's/^/  /' <<<"$wo"
		exit 1
	fi

	ro=$("$DEVMEM2" "$h" w 2>&1 || true)
	rh=$(read_hex "$ro")
	if [[ -n "$rh" ]]; then
		got=$(printf %08X $((16#$rh)))
		if [[ $got == "$want" ]]; then
			printf '[col %2d] %s OK\n' "$col" "$h"
			continue
		fi
		printf '[col %2d] %s BAD read=%s want=%s\n' "$col" "$h" "$got" "$want"
	else
		printf '[col %2d] %s BAD read=?\n' "$col" "$h"
		sed 's/^/  /' <<<"$ro"
	fi
	exit 1
done

echo
echo "All OK."
