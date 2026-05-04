#!/usr/bin/env bash

set -euo pipefail

# Per-column uC wakeup + firmware handshake (cert) state via devmem2.
# Defaults match VE2 column stride; override with env if your map differs.

DEVMEM2=${DEVMEM2:-devmem2}
STATE_REG=${STATE_REG:-0x200000880A0}
WAKE_REG=${WAKE_REG:-0x200000C0004}
WAKE_VAL=${WAKE_VAL:-1}
EXPECT_STATE=${EXPECT_STATE:-0x0FFE}
STATE_MASK=${STATE_MASK:-0xFFFF}
COL_LAST=${COL_LAST:-35}
COL_SHIFT=${COL_SHIFT:-25}
POST_WAKE_SLEEP=${POST_WAKE_SLEEP:-0.05}

strip() { local z=${1#0x}; echo "${z#0X}"; }

state_base=$((16#$(strip "$STATE_REG")))
wake_base=$((16#$(strip "$WAKE_REG")))
mask=$((16#$(strip "$STATE_MASK")))
want=$((16#$(strip "$EXPECT_STATE")))
want=$((want & mask))

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
	off=$((col << COL_SHIFT))
	read_addr=$((state_base + off))
	wake_addr=$((wake_base + off))
	rh=$(printf '0x%X' "$read_addr")
	wh=$(printf '0x%X' "$wake_addr")

	set +e
	wo=$("$DEVMEM2" "$wh" w "$WAKE_VAL" 2>&1)
	wr=$?
	set -e
	if ((wr != 0)); then
		printf '[col %2d] wakeup %s WRITE_FAIL write_rc=%s\n' "$col" "$wh" "$wr"
		[[ -n "$wo" ]] && sed 's/^/  /' <<<"$wo"
		exit 1
	fi

	if [[ -n "$POST_WAKE_SLEEP" ]]; then
		sleep "$POST_WAKE_SLEEP"
	fi

	ro=$("$DEVMEM2" "$rh" w 2>&1 || true)
	got_raw=$(read_hex "$ro")
	if [[ -z "$got_raw" ]]; then
		printf '[col %2d] state %s READ_FAIL read=?\n' "$col" "$rh"
		sed 's/^/  /' <<<"$ro"
		exit 1
	fi

	got=$((16#$got_raw))
	got_masked=$((got & mask))
	if ((got_masked == want)); then
		printf '[col %2d] state %s OK read=0x%X (masked=0x%X want=0x%X)\n' \
			"$col" "$rh" "$got" "$got_masked" "$want"
		continue
	fi
	printf '[col %2d] state %s BAD read=0x%X masked=0x%X want=0x%X (not awake / bad handshake)\n' \
		"$col" "$rh" "$got" "$got_masked" "$want"
	exit 1
done

echo
echo "All OK."