# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2023 Advanced Micro Devices, Inc. All rights reserved.
#
# DPU script to generate DPU instructions for a AIE shim DMA loopback test.
# This script loops 1GB of data through 4 columns utilizing 2 input and 2
# output DMA channels per Shim DMA.
#
set_grid -grid 0

# size is in number of words
set transferSize 0x10000000

set shim_row 0
set columns {0 1 2 3}
set channels {0 1}
set in_bds {1 2}
set out_bds {3 4}
set burst_length 16
set ax_cache 2
set step 1

set channels_per_column [llength $channels]
set active_chans [expr $channels_per_column * [llength $columns]]
set len_per_bd [expr $transferSize / $active_chans]
set addrs {}

set column_idx 0
foreach col $columns {
	set channel_idx 0
	foreach channel $channels {
		set idx [expr (($column_idx * $channels_per_column) + $channel_idx)]
		set addr [expr "$len_per_bd * $idx * 4"]
		set addrs [linsert $addrs $idx $addr]
		incr channel_idx
	}
	incr column_idx
}

# TCT routing
foreach column $columns {
	me_route -col $column -row $shim_row -slave_dir P -slave_id 0 -master_dir S -master_id 0
}

# CHAN 0
foreach column $columns {
	me_route -col $column -row $shim_row -slave_dir D -slave_id [lindex $channels 0] -master_dir D -master_id [lindex $channels 0]
}

# CHAN 1	
foreach column $columns {
	me_route -col $column -row $shim_row -slave_dir D -slave_id [lindex $channels 1] -master_dir D -master_id [lindex $channels 1]
}

# BDs: Col 0
set in00 [ me_dma -col [lindex $columns 0] -row $shim_row -name in00 -type MM2S -address [lindex $addrs 0] -length $len_per_bd -channel [lindex $channels 0] -bd [lindex $in_bds 0] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set out00 [ me_dma -col [lindex $columns 0] -row $shim_row -name out00 -type S2MM -address [lindex $addrs 0] -length $len_per_bd -channel [lindex $channels 0] -bd [lindex $out_bds 0] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set in01 [ me_dma -col [lindex $columns 0] -row $shim_row -name in01 -type MM2S -address [lindex $addrs 1] -length $len_per_bd -channel [lindex $channels 1] -bd [lindex $in_bds 1] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set out01 [ me_dma -col [lindex $columns 0] -row $shim_row -name out01 -type S2MM -address [lindex $addrs 1] -length $len_per_bd -channel [lindex $channels 1] -bd [lindex $out_bds 1] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]

# BDs: Col 1
set in10 [ me_dma -col [lindex $columns 1] -row $shim_row -name in10 -type MM2S -address [lindex $addrs 2] -length $len_per_bd -channel [lindex $channels 0] -bd [lindex $in_bds 0] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set out10 [ me_dma -col [lindex $columns 1] -row $shim_row -name out10 -type S2MM -address [lindex $addrs 2] -length $len_per_bd -channel [lindex $channels 0] -bd [lindex $out_bds 0] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set in11 [ me_dma -col [lindex $columns 1] -row $shim_row -name in11 -type MM2S -address [lindex $addrs 3] -length $len_per_bd -channel [lindex $channels 1] -bd [lindex $in_bds 1] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set out11 [ me_dma -col [lindex $columns 1] -row $shim_row -name out11 -type S2MM -address [lindex $addrs 3] -length $len_per_bd -channel [lindex $channels 1] -bd [lindex $out_bds 1] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]

# BDs: Col 2
set in20 [ me_dma -col [lindex $columns 2] -row $shim_row -name in20 -type MM2S -address [lindex $addrs 4] -length $len_per_bd -channel [lindex $channels 0] -bd [lindex $in_bds 0] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set out20 [ me_dma -col [lindex $columns 2] -row $shim_row -name out20 -type S2MM -address [lindex $addrs 4] -length $len_per_bd -channel [lindex $channels 0] -bd [lindex $out_bds 0] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set in21 [ me_dma -col [lindex $columns 2] -row $shim_row -name in21 -type MM2S -address [lindex $addrs 5] -length $len_per_bd -channel [lindex $channels 1] -bd [lindex $in_bds 1] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set out21 [ me_dma -col [lindex $columns 2] -row $shim_row -name out21 -type S2MM -address [lindex $addrs 5] -length $len_per_bd -channel [lindex $channels 1] -bd [lindex $out_bds 1] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]

# BDs: Col 3
set in30 [ me_dma -col [lindex $columns 3] -row $shim_row -name in30 -type MM2S -address [lindex $addrs 6] -length $len_per_bd -channel [lindex $channels 0] -bd [lindex $in_bds 0] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set out30 [ me_dma -col [lindex $columns 3] -row $shim_row -name out30 -type S2MM -address [lindex $addrs 6] -length $len_per_bd -channel [lindex $channels 0] -bd [lindex $out_bds 0] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set in31 [ me_dma -col [lindex $columns 3] -row $shim_row -name in31 -type MM2S -address [lindex $addrs 7] -length $len_per_bd -channel [lindex $channels 1] -bd [lindex $in_bds 1] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]
set out31 [ me_dma -col [lindex $columns 3] -row $shim_row -name out31 -type S2MM -address [lindex $addrs 7] -length $len_per_bd -channel [lindex $channels 1] -bd [lindex $out_bds 1] -burst_length $burst_length -axCache $ax_cache -step_1d $step ]

# DMA
enable_dma -id $out00 -enable_token 1
enable_dma -id $in00
enable_dma -id $out01 -enable_token 1
enable_dma -id $in01
enable_dma -id $out10 -enable_token 1
enable_dma -id $in10
enable_dma -id $out11 -enable_token 1
enable_dma -id $in11
enable_dma -id $out20 -enable_token 1
enable_dma -id $in20
enable_dma -id $out21 -enable_token 1
enable_dma -id $in21
enable_dma -id $out30 -enable_token 1
enable_dma -id $in30
enable_dma -id $out31 -enable_token 1
enable_dma -id $in31

# TCT
token_check -col [lindex $columns 0] -row $shim_row -tokenValue [expr {1 << 8} | {1 << 16} | {[lindex $channels 0] << 24}]
token_check -col [lindex $columns 0] -row $shim_row -tokenValue [expr {1 << 8} | {1 << 16} | {[lindex $channels 1] << 24}]
token_check -col [lindex $columns 1] -row $shim_row -tokenValue [expr {1 << 8} | {1 << 16} | {[lindex $channels 0] << 24}]
token_check -col [lindex $columns 1] -row $shim_row -tokenValue [expr {1 << 8} | {1 << 16} | {[lindex $channels 1] << 24}]
token_check -col [lindex $columns 2] -row $shim_row -tokenValue [expr {1 << 8} | {1 << 16} | {[lindex $channels 0] << 24}]
token_check -col [lindex $columns 2] -row $shim_row -tokenValue [expr {1 << 8} | {1 << 16} | {[lindex $channels 1] << 24}]
token_check -col [lindex $columns 3] -row $shim_row -tokenValue [expr {1 << 8} | {1 << 16} | {[lindex $channels 0] << 24}]
token_check -col [lindex $columns 3] -row $shim_row -tokenValue [expr {1 << 8} | {1 << 16} | {[lindex $channels 1] << 24}]
