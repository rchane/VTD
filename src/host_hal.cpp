// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2023-2024 Advanced Micro Devices, Inc. All rights reserved.

/* This host application measures the TOPS value of GEMM operations.
 * The DPU sequence reads matrix values from the DDR into the AIE array
 * and performs multiply and accumulate (MAC) operations.
 * Essentially, we are doing 4 unrolled loop of 8x8_8x8 matmult.
 * 1. Each 8x8_8x8 matmult involves 8x8x8=512 MAC or 512*2 OP=1024 OPs.
 * 2. Total inner*outer loop count= 2*2*12*4 (4 for unrolled loop)=192.
 * 3. Total OPs = 192*1024 = 192K OPs.
 * 4. GOPS/core = 192K/(Cycle_count*HCLK period)= 192*1024/(229*1 ns)= 0.8585*10^12 OP/s= 0.8585 TOPS/core
 * 5. Repeat #4 for each core - ensure you enter cycle count for each core.
 * 6. HCLK period will be a function of the DPM state (for DPM7, it will be 1/1.8GHz).
*/

#include <iostream>
#include <string>
#include <chrono>
#include <thread>

// XRT includes
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"
#include "xrt/xrt_bo.h"

#include "CLI11.hpp"
#include <cstdlib>

#define HOST_APP 1

size_t get_instr_size(std::string &fname) {
  std::ifstream myfile (fname);
  size_t i = 0;
  if (myfile.is_open())
  {
    printf("Open instr successfully!\n");
    std::string line;
    while (getline (myfile,line))
    {
      if(line.at(0)!='#'){
        i++;
      }
    }
    myfile.close();
  }
  return i;
}

// Copy values from text files into buff, expecting values are ascii encoded hex
void init_hex_buf(int* buff, size_t bytesize, std::string &filename) {
  std::ifstream ifs(filename);

  if (!ifs.is_open()) {
    std::cout << "Failure opening file " + filename + " for reading!!" << std::endl;
    abort();
  }

  std::string line;
  while (getline (ifs,line))
  {
    if(line.at(0)!='#'){
      unsigned int temp = 0;
      std::stringstream ss(line);
      ss >> std::hex >> temp;
      *(buff++) = temp;
    }
  }
}

void init_instr_buf(xrt::bo &bo_instr, size_t instr_size, std::string& instr_path) {
  init_hex_buf(bo_instr.map<int*>(), instr_size, instr_path);
}

int main() {
  unsigned int failed = 0;
  std::string instr_path = "sequences/gemm_int8.txt";

  try {
    std::cout << "Host test code start..." << std::endl;
    std::cout << "Host test code is creating device object..." << std::endl;
    unsigned int device_index = 0;
    auto device = xrt::device(device_index);
    std::string xclbinFileName = "gemm_npu4.xclbin";
    std::cout << "Host test code is loading xclbin object..." << xclbinFileName << std::endl;
    auto xclbin = xrt::xclbin(xclbinFileName);

    // Determine The DPU Kernel Name
    auto xkernels = xclbin.get_kernels();

    auto iteratorFound = std::find_if(xkernels.begin(), xkernels.end(), [](xrt::xclbin::kernel& k) {
      auto name = k.get_name();

      bool found = ((name.rfind("DPU",0) == 0) || // Starts with "DPU"
                    (name.rfind("dpu",0) == 0));   // Starts with "dpu"
      return found;
    });

    if (iteratorFound == xkernels.end())
        throw std::runtime_error("Error: xclbin does not have a valid kernel");

    xrt::xclbin::kernel& xkernel = *iteratorFound;
    auto kernelName = xkernel.get_name();
    
    std::cout << "Host test code found kernel: " << kernelName << std::endl;
    std::cout << "Host code is registering xclbin to the device..." << std::endl;
    device.register_xclbin(xclbin);

    std::cout << "Host code is creating hw_context..." << std::endl;
    xrt::hw_context context(device, xclbin.get_uuid());

    std::cout << "Host test code is creating kernel object..." << std::endl;
    auto kernel = xrt::kernel(context, kernelName);

    // Create BOs
    static constexpr uint32_t size_4K   = 0x1000;
    static constexpr uint32_t offset_3K = 0x0C00;

    size_t instr_word_size = get_instr_size(instr_path);
    if (instr_word_size == 0)
        throw std::runtime_error("Error: Why do instructions have zero length?");

    // Create BOs
    auto bo_instr = xrt::bo(device, instr_word_size * sizeof(int), XCL_BO_FLAGS_CACHEABLE, kernel.group_id(5));

    // Init BOs
    // Load them with data from files
    init_instr_buf(bo_instr, instr_word_size, instr_path); // DPU sequence gemm_int8.txt
    
    // Sync Input BO
    bo_instr.sync(XCL_BO_SYNC_BO_TO_DEVICE);

    // results BO syncs profile result from device
    auto bo_result = xrt::bo(device, size_4K, XCL_BO_FLAGS_CACHEABLE, kernel.group_id(5));

    // Set kernel argument and trigger it to run
    uint64_t opcode = HOST_APP;

    /* Each record timer entry has 32bit ID and 32bit AIE Timer low value.
    * Also, the first 32 bit in the buffer is used to store total number 
    * of record timer entries written so far. So, max_count_in_size_3K is 1 less 
    * than total number of entries possible in 3K buffer section.
    */ 
    static constexpr uint32_t max_count_in_size_3K = (offset_3K / (2 * sizeof(uint32_t))) - 1;

    auto Total_TOPS = 0.0;
    auto Total_cycle_count = 0.0;
    auto temp_TOPS_per_core = 0.0;

    // This number is hardcoded temporarily, but it will be queried from the xbutil
    int IPUHCLK = 1810; //in MHz
    std::cout<<"Running the performance test with "<< IPUHCLK <<" MHz AIE clock..." << std::endl;

    auto IPUHCLK_Period= 1000000000.0/(IPUHCLK*1000000); //1810 MHz

    auto Number_MACs = 8*8*8; //512
    auto Number_OPs = Number_MACs*2; //1024
    auto Total_inner_outer_loop_count=2*2*12*4; //192
    auto Total_OPs = Number_OPs*Total_inner_outer_loop_count; //192K OPs

    auto run = kernel(opcode, NULL, NULL, NULL, NULL, bo_instr, instr_word_size, NULL);
    run.wait2();

    std::cout << "Total OPs: " << Total_OPs << std::endl;

    auto result_bo_map = bo_result.map<uint8_t*>();

    bo_result.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
    // Add time delay to wait till the device has transferred data back to the host
    std::this_thread::sleep_for(std::chrono::milliseconds(10));

    uint32_t* core_ptr = reinterpret_cast<uint32_t*>(result_bo_map+offset_3K);
    uint32_t NumofCores = 32;

    Total_TOPS = 0.0;
    Total_cycle_count = 0.0;
    temp_TOPS_per_core = 0.0;
    if (NumofCores <= max_count_in_size_3K) {
      for (uint32_t i = 0 ; i < NumofCores; i++) {
        auto Cycle_Count = *core_ptr;
        temp_TOPS_per_core = Total_OPs/(IPUHCLK_Period*Cycle_Count*1000);
        Total_cycle_count = Total_cycle_count + Cycle_Count;
        Total_TOPS = Total_TOPS + temp_TOPS_per_core;
        core_ptr++;
      }
    
    std::cout << "Average cycle count: " << Total_cycle_count/NumofCores << std::endl;
    std::cout << "Total execution time: " << IPUHCLK_Period*(Total_cycle_count/NumofCores) << " ns"<< std::endl;
    std::cout << "Total TOPS with "<< IPUHCLK <<" MHz AIE frequency: " << Total_TOPS << std::endl;
    }

    /*
    1.	Essentially, we are doing 4 unrolled loop of 8x8_8x8 matmult.
    2.	Each 8x8_8x8 matmult involves 8x8x8=512 MAC or 512*2 OP=1024 OPs.
    3.	Total inner*outer loop count= 2*2*12*4 (4 for unrolled loop)=192.
    4.	Total OPs= 192*1024= 192K OPs.
    5.	GOPS/core = 192K/(Cycle_count*HCLK period)= 192*1024/(232*1 ns)= 0.82*10^12 OP/s= 0.82 TOPS
    6.	Repeat #5 for each core- ensure you enter cycle count for each core.
    7.	HCLK period will be a function of the DPM state (for DPM7, it will be 1/1.8GHz).
    */
  }
  catch (const std::exception& ex) {
    std::cout << "ERROR: Caught exception: " << ex.what() << '\n';
    failed = 1;
  }

  if (!failed) {
      std::cout << "TEST PASSED!" << std::endl;
  }
  else {
      std::cout << "TEST FAILED!" << std::endl;
  }

  return (failed ? EXIT_FAILURE : EXIT_SUCCESS);
}

