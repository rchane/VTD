#!/usr/bin/env bash

set -euo pipefail

# This recipe installs under .../amdxdna/bins/t50/; other packages use the parent tree.
AMDXDNA_BINS="${AMDXDNA_BINS:-/usr/share/amdxdna/bins/t50}"
AMDXDNA_BINS_TOP="${AMDXDNA_BINS_TOP:-/usr/share/amdxdna/bins}"
DEVICE="${DEVICE:-0}"

# This launcher lives in AMDXDNA_BINS; helper scripts each have a subdirectory there.
PS_AIE_CONNECTIONS_SH="${PS_AIE_CONNECTIONS_SH:-${AMDXDNA_BINS}/ps_aie_connections/ps_aie_connections.sh}"
PS_AIE_CERT_WAKEUP_SH="${PS_AIE_CERT_WAKEUP_SH:-${AMDXDNA_BINS}/ps_aie_cert_wakeup/ps_aie_cert_wakeup.sh}"

usage() {
	cat <<EOF
Usage: ${0##*/} [all | N [N ...]]
  (no arguments)  Run checks 1–9 in order (default)
  all               Same as default
  1                 xrt-smi latency test
  2                 xrt-smi throughput test
  3                 xrt-smi cmd-chain-latency test
  4                 xrt-smi cmd-chain-throughput test
  5                 xrt-runner aie_ddr_connections test
  6                 ps_aie_connections/ps_aie_connections.sh (all columns read/write check)
  7                 xrt-runner ps_aie_ddr_connections test
  8                 ps_aie_cert_wakeup/ps_aie_cert_wakeup.sh (uC wakeup + handshake 0x0FFE per column)
  9                 xrt-runner shim_dma_bandwidth test (shim DMA BW)

Environment:
  DEVICE=$DEVICE (default 0)
  AMDXDNA_BINS=$AMDXDNA_BINS (this recipe; default .../bins/t50)
  AMDXDNA_BINS_TOP=$AMDXDNA_BINS_TOP (sibling packages e.g. aie_ddr_connections; default .../bins)
  PS_AIE_CONNECTIONS_SH=$PS_AIE_CONNECTIONS_SH
  PS_AIE_CERT_WAKEUP_SH=$PS_AIE_CERT_WAKEUP_SH
EOF
}

banner() {
	printf '\n======== %s ========\n' "$1"
}

run_1_latency() {
	banner '1: xrt-smi validate -r latency'
	xrt-smi validate -r latency -d "$DEVICE"
}

run_2_throughput() {
	banner '2: xrt-smi validate -r throughput'
	xrt-smi validate -r throughput -d "$DEVICE"
}

run_3_cmd_chain_latency() {
	banner '3: xrt-smi validate --advanced -r cmd-chain-latency'
	xrt-smi validate --advanced -r cmd-chain-latency -d "$DEVICE"
}

run_4_cmd_chain_throughput() {
	banner '4: xrt-smi validate --advanced -r cmd-chain-throughput'
	xrt-smi validate --advanced -r cmd-chain-throughput -d "$DEVICE"
}

run_5_aie_ddr() {
	local script="${AMDXDNA_BINS}/aie_ddr_connections/runner.json"
	banner "5: xrt-runner --script ${script}"
	xrt-runner --script "$script"
}

run_6_ps_aie_connections() {
	local s="$PS_AIE_CONNECTIONS_SH"
	banner "6: ${s}"
	[[ -x "$s" ]] || {
		echo "error: not executable: $s" >&2
		return 1
	}
	bash "$s"
}

run_7_ps_aie_ddr_connections() {
	local script="${AMDXDNA_BINS}/ps_aie_ddr_connections/runner.json"
	banner "7: xrt-runner --script ${script}"
	xrt-runner --script "$script"
}

run_8_ps_aie_cert_wakeup() {
	local s="$PS_AIE_CERT_WAKEUP_SH"
	banner "8: ${s}"
	[[ -x "$s" ]] || {
		echo "error: not executable: $s" >&2
		return 1
	}
	bash "$s"
}

run_9_shim_dma_bandwidth() {
	local script="${AMDXDNA_BINS}/shim_dma_bandwidth/runner.json"
	banner "9: xrt-runner --script ${script}"
	xrt-runner --script "$script"
}

dispatch() {
	local n=$1
	case "$n" in
		1) run_1_latency ;;
		2) run_2_throughput ;;
		3) run_3_cmd_chain_latency ;;
		4) run_4_cmd_chain_throughput ;;
		5) run_5_aie_ddr ;;
		6) run_6_ps_aie_connections ;;
		7) run_7_ps_aie_ddr_connections ;;
		8) run_8_ps_aie_cert_wakeup ;;
		9) run_9_shim_dma_bandwidth ;;
		-h | --help)
			usage
			exit 0
			;;
		*)
			echo "error: unknown selection '$n' (use 1–9, all, or --help)" >&2
			exit 1
			;;
	esac
}

main() {
	if [[ $# -eq 0 ]]; then
		set -- all
	fi

	local failed=0
	local n
	for n in "$@"; do
		if [[ "$n" == all ]]; then
			local i
			for i in 1 2 3 4 5 6 7 8 9; do
				dispatch "$i" || failed=1
			done
		else
			dispatch "$n" || failed=1
		fi
	done

	exit "$failed"
}

main "$@"
