# Validation Test Data (VTD)

This repository hosts the runtime artifacts required characterisizing AI-Engine.

```
sequences
  |-- df_bw_4col.txt
  |-- df_bw.txt #non-production
  |-- tct_1col.txt
  |-- tct_4col.txt
  |-- gemm_int8.txt

xclbin_prod
  |-- validate_npu.xclbin #phoenix
  |-- validate_npu4.xclbin #strixB0 (same xclbin can be used for Strix A0)
  |-- gemm_npu4.xclbin #strixB0
```
Currently, this suite maintains the following host applications,
- DF bandwidth 
- TCT throughput
- GeMM TOPs


NOTE: All the host code resides in xbutil, please do not add any more application code here
