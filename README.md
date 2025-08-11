<!---SPDX-License-Identifier: Apache-2.0-->
<!---Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.-->

# Validation Test Data (VTD)

This repository hosts the runtime artifacts required characterisizing AI-Engine.

```
elf
  |-- nop_npu3.elf
  |-- nop_npu4.elf
  |-- preemption_noop_4x1.elf
  |-- preemption_noop_4x2.elf
  |-- preemption_noop_4x4.elf
  |-- preemption_noop_4x8.elf
  |-- preemption_memtile_4x1.elf
  |-- preemption_memtile_4x2.elf
  |-- preemption_memtile_4x4.elf
  |-- preemption_memtile_4x8.elf

xclbin_prod
  |-- validate_npu.xclbin #phoenix
  |-- validate_npu4.xclbin #strixB0 (same xclbin can be used for Strix A0)
  |-- gemm_npu4.xclbin #strixB0
  |-- validate_npu3.xclbin #npu3
  |-- mobilenet_npu4_4x4.xclbin #strixB0

Note: elf xclbins will soon be removed
```
Currently, this suite maintains the following host applications,
- DF bandwidth 
- TCT throughput
- GeMM TOPs
- Premeption


NOTE: All the host code resides in xrt-smi, please do not add any more application code here
