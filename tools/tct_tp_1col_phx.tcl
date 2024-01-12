set_grid -grid 0
# size is in number of words
set transferSize 1
#set transferSize 268435456

set ddrSrcAddr 0x0
set ddrDstAddr 0x0

set slaveCol 1
set slaveRow 0

set masterCol 1
set masterRow 0

set dmaChan 0
set token 0x00010100
#set dmaChan 1
#set token 0x01010100

me_route -col $slaveCol -row $slaveRow -slave_dir D -slave_id $dmaChan -master_dir D -master_id $dmaChan

me_route -col $slaveCol -row $slaveRow -slave_dir P -slave_id 0 -master_dir S -master_id 0

set mm2s [ me_dma -col $slaveCol -row $slaveRow   -name mm2s -type MM2S -address $ddrSrcAddr -length $transferSize -channel $dmaChan -bd 2 -burst_length 16 -axCache 2 -step_1d 1 ]

set s2mm [ me_dma -col $masterCol -row $masterRow -name s2mm -type S2MM -address $ddrDstAddr -length $transferSize -channel $dmaChan -bd 5 -burst_length 16 -axCache 2 -step_1d 1 ]


for { set k 0 } { $k < 10000 } { incr k } {
enable_dma -id $s2mm -enable_token 1
enable_dma -id $mm2s
token_check -col [expr $masterCol + 0] -row $masterRow -tokenValue $token
}
