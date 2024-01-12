set_grid -grid 0

set core1 [list 0 1 ]
set core2 [list 0 1 ]

puts "\n core1 = $core1\n"

set slaveCol [lindex $core1 1] 
set slaveRow [lindex $core1 0] 


set masterCol [lindex $core2 1] 
set masterRow [lindex $core2 0]

set ddrSrcAddr0 0x0000000
set ddrSrcAddr1 0x0000000
set ddrSrcAddr2 0x0000000
set ddrSrcAddr3 0x0000000

set ddrDstAddr0 0x0000000
set ddrDstAddr1 0x0000004
set ddrDstAddr2 0x0000008
set ddrDstAddr3 0x000000C

set transferSize 1

set dmaChan 0
set token 0x00010100
#set dmaChan 1
#set token 0x01010100 ### Change bd and try

me_route -col [expr 0 + $slaveCol ] -row $slaveRow -slave_dir D -slave_id $dmaChan -master_dir D -master_id $dmaChan
me_route -col [expr 1 + $slaveCol ] -row $slaveRow -slave_dir D -slave_id $dmaChan -master_dir D -master_id $dmaChan
me_route -col [expr 2 + $slaveCol ] -row $slaveRow -slave_dir D -slave_id $dmaChan -master_dir D -master_id $dmaChan
me_route -col [expr 3 + $slaveCol ] -row $slaveRow -slave_dir D -slave_id $dmaChan -master_dir D -master_id $dmaChan

me_route -col [expr 0 + $slaveCol ] -row $slaveRow -slave_dir P -slave_id $dmaChan -master_dir S -master_id $dmaChan
me_route -col [expr 1 + $slaveCol ] -row $slaveRow -slave_dir P -slave_id $dmaChan -master_dir S -master_id $dmaChan
me_route -col [expr 2 + $slaveCol ] -row $slaveRow -slave_dir P -slave_id $dmaChan -master_dir S -master_id $dmaChan
me_route -col [expr 3 + $slaveCol ] -row $slaveRow -slave_dir P -slave_id $dmaChan -master_dir S -master_id $dmaChan

set mm2s1 [ me_dma -col [expr 0 + $slaveCol ] -row $slaveRow   -name mm2s1 -type MM2S -address $ddrSrcAddr0 -length $transferSize -channel $dmaChan -bd 2 -burst_length 16 -axCache 2 -step_1d 1 ]
set mm2s2 [ me_dma -col [expr 1 + $slaveCol ] -row $slaveRow   -name mm2s2 -type MM2S -address $ddrSrcAddr1 -length $transferSize -channel $dmaChan -bd 2 -burst_length 16 -axCache 2 -step_1d 1 ]
set mm2s3 [ me_dma -col [expr 2 + $slaveCol ] -row $slaveRow   -name mm2s3 -type MM2S -address $ddrSrcAddr2 -length $transferSize -channel $dmaChan -bd 2 -burst_length 16 -axCache 2 -step_1d 1 ]
set mm2s4 [ me_dma -col [expr 3 + $slaveCol ] -row $slaveRow   -name mm2s4 -type MM2S -address $ddrSrcAddr3 -length $transferSize -channel $dmaChan -bd 2 -burst_length 16 -axCache 2 -step_1d 1 ]

set s2mm1 [ me_dma -col [expr 0 + $masterCol ] -row $masterRow -name s2mm1 -type S2MM -address $ddrDstAddr0 -length $transferSize -channel $dmaChan -bd 4 -burst_length 16 -axCache 2 -step_1d 1 ]
set s2mm2 [ me_dma -col [expr 1 + $masterCol ] -row $masterRow -name s2mm2 -type S2MM -address $ddrDstAddr1 -length $transferSize -channel $dmaChan -bd 4 -burst_length 16 -axCache 2 -step_1d 1 ]
set s2mm3 [ me_dma -col [expr 2 + $masterCol ] -row $masterRow -name s2mm3 -type S2MM -address $ddrDstAddr2 -length $transferSize -channel $dmaChan -bd 4 -burst_length 16 -axCache 2 -step_1d 1 ]
set s2mm4 [ me_dma -col [expr 3 + $masterCol ] -row $masterRow -name s2mm4 -type S2MM -address $ddrDstAddr3 -length $transferSize -channel $dmaChan -bd 4 -burst_length 16 -axCache 2 -step_1d 1 ]

for { set k 0 } { $k < 5000 } { incr k } {
enable_dma -id $s2mm1 -enable_token 1
enable_dma -id $s2mm2 -enable_token 1
enable_dma -id $s2mm3 -enable_token 1
enable_dma -id $s2mm4 -enable_token 1

enable_dma -id $mm2s1
enable_dma -id $mm2s2
enable_dma -id $mm2s3
enable_dma -id $mm2s4

token_check -col [expr $masterCol + 0] -row $masterRow -tokenValue 0x00010100
token_check -col [expr $masterCol + 1] -row $masterRow -tokenValue 0x00010100
token_check -col [expr $masterCol + 2] -row $masterRow -tokenValue 0x00010100
token_check -col [expr $masterCol + 3] -row $masterRow -tokenValue 0x00010100
}
