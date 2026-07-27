#!/usr/bin/env bash

set -euo pipefail

# PS↔AIE column read/write check via devmem2.
# VE2 column-memory base is fixed; MMIO targets are clamped to the AIE aperture.

readonly DEVMEM2=devmem2
readonly VE2_AIE_BASE=0x20000000000
readonly VE2_AIE_SIZE=0x00080000000
readonly ADDR_BASE=0x20000000000
readonly EXPECT=0xDEADBEEF
readonly COL_SHIFT=25
readonly COL_OFFSET=$((1 << 20))
readonly COL_LAST=36

strip() { local z=${1#0x}; echo "${z#0X}"; }

in_aie_window() {
	local a=$1
	((a >= VE2_AIE_BASE && a < VE2_AIE_BASE + VE2_AIE_SIZE))
}

assert_aie_window() {
	local addr=$1 label=$2
	in_aie_window "$addr" || {
		printf 'error: refusing OOB MMIO %s @0x%X (outside VE2 AIE window [0x%X, 0x%X))\n' \
			"$label" "$addr" "$VE2_AIE_BASE" $((VE2_AIE_BASE + VE2_AIE_SIZE)) >&2
		exit 1
	}
}

want=$(printf %08X $((16#$(strip "$EXPECT"))))
base=$ADDR_BASE

command -v "$DEVMEM2" >/dev/null 2>&1 || {
	echo "error: $DEVMEM2 not found" >&2
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
	a=$((base + (col << COL_SHIFT) + COL_OFFSET))
	h=$(printf '0x%08X' "$a")

	assert_aie_window "$a" "col=$col"

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
