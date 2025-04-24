// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.

/* This host application calculates the DF bandwidth per AIE shim DMA channel.
 * The DPU sequence loops back the input data from DDR through a AIE MM2S Shim
 * DMA channel back to DDR through a S2MM Shim DMA channel.  The data movement
 * within the AIE array follows the lowest latency path i.e. movement is
 * restricted to just the Shim tile. No memtile DMA or memtile memory is
 * utilized.  While the BD addressing scheme is linear, the DPU sequence polls
 * for the BD completion. The data size for one test iteration is 1GB.
 */

#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

// XRT includes
#include "xrt/xrt_bo.h"
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"

constexpr unsigned long int dpu_instr_str_len = 8;
constexpr unsigned long int host_app = 1;
constexpr unsigned long int tnx_len_gb = 1;
constexpr unsigned long int tnx_len = tnx_len_gb * 1024 * 1024 * 1024;
constexpr unsigned long int tnx_word_count = tnx_len / 4;

std::string dpu_instr("sequences/df_bw_4col.txt");

/* Copy values from text file into buff, expecting values are ASCII encoded
 * 4-Byte hexadecimal values.
 */
void
init_instr_buf(xrt::bo &bo_instr)
{
  auto instr = bo_instr.map<int*>();
  std::string line;
  std::ifstream ifs(dpu_instr);

  if (!ifs.is_open())
    throw std::runtime_error("Error: Failure opening file " + dpu_instr + " for reading!!\n");

  // Copy 4-Byte hex values to the instruction buffer, ignoring comments
  while (getline(ifs, line)) {
    if (line.at(0) == '#')
      continue;

    std::stringstream ss(line);
    unsigned int word = 0;

    ss.seekp(0, std::ios::end);
    if (ss.tellp() != dpu_instr_str_len)
      throw std::runtime_error("Error: Invalid DPU instruction size\n");

    ss >> std::hex >> word;
    *(instr++) = word;
  }
}

size_t
get_instr_size(std::string &fname)
{
  std::string line;
  size_t size = 0;

  std::ifstream file(fname);
  if (!file.is_open())
    throw std::runtime_error("Error: Failure opening file " + fname + " for reading!!\n");

  // DPU sequence text file is list of 32-bit hex values separated by newline
  // Comments within the file are identified by a '#' prefix
  while (getline(file, line)) {
    if (line.at(0) != '#')
      size++;
  }

  if (size == 0)
    throw std::runtime_error("Error: Invalid DPU instruction length");

  return size;
}

void
run_test_iterations(const std::string &xclbinFileName, xrt::device &device, int tid, int it_max)
{
  auto xclbin = xrt::xclbin(xclbinFileName);

  // Determine The DPU Kernel Name
  auto xkernels = xclbin.get_kernels();
  auto xkernel = *std::find_if(xkernels.begin(), xkernels.end(), [](xrt::xclbin::kernel& k) {
    auto name = k.get_name();
    // Starts with "DPU"
    return name.rfind("DPU", 0) == 0;
  });

  if (!xkernel)
    throw std::runtime_error("Error: Failure to find DPU kernel in the XCLBIN!\n");

  auto kernelName = xkernel.get_name();

  device.register_xclbin(xclbin);
  xrt::hw_context context(device, xclbin.get_uuid());

  auto dpu = xrt::kernel(context, kernelName);

  size_t instr_size = get_instr_size(dpu_instr);

  auto instr = xrt::bo(device, instr_size * sizeof(int), XCL_BO_FLAGS_CACHEABLE, dpu.group_id(5));
  auto in = xrt::bo(device, tnx_len, XRT_BO_FLAGS_HOST_ONLY, dpu.group_id(1));
  auto out = xrt::bo(device, tnx_len, XRT_BO_FLAGS_HOST_ONLY, dpu.group_id(3));

  init_instr_buf(instr);

  instr.sync(XCL_BO_SYNC_BO_TO_DEVICE);

  std::cout << "Transaction word count: 0x" << std::hex << tnx_word_count << "\n";
  auto in_mapped = in.map<int*>();
  auto out_mapped = out.map<int*>();
  for (unsigned long int i = 0; i < tnx_word_count; i++) {
    in_mapped[i] = rand() % 8192;
    out_mapped[i] = 0;
  }
  in.sync(XCL_BO_SYNC_BO_TO_DEVICE);
  out.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

  std::cout << "Iteration count: " << std::dec << it_max << "\n" ;

  auto run = xrt::run(dpu);
  run.set_arg(0, host_app);
  run.set_arg(1, in);
  run.set_arg(2, NULL);
  run.set_arg(3, out);
  run.set_arg(4, NULL);
  run.set_arg(5, instr);
  run.set_arg(6, instr_size);
  run.set_arg(7, NULL);

  // All iterations in the same thread share the same hw context
  auto start = std::chrono::high_resolution_clock::now();
  for (int i = 0; i < it_max; i++) {
    run.start();
    run.wait2();
  }
  auto end = std::chrono::high_resolution_clock::now();

  std::cout << "Data transfer complete. Checking results...\n";

  out.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

  for (unsigned long int i = 0; i < tnx_word_count; i++) {
    if (out_mapped[i] == in_mapped[i])
      continue;

    std::cout << "In[" << i << "]: " << in_mapped[i] << " | Out[" << i << "]: " << out_mapped[i] << "\n";
    throw std::runtime_error("Error: Output data mismatch!\nTEST FAILED!\n");
  }

  double elapsedSecs = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
  // tnx_len_gb data is read and written in parallel
  double bw = (tnx_len_gb * it_max * 2 * 1e6) / (elapsedSecs);

  std::cout << "Time taken: " << elapsedSecs << " us\n";
  std::cout << "AIE DF bandwidth: " << bw << " GB/s\n";
}

void
run(int argc, char **argv)
{
  int num_thread, it_max;

  // Set the number of threads and iterations
  // Default: 1 thread, 1 iteration
  if (argc == 2) {
    num_thread = 1;
    it_max = 600;
  } else if (argc == 3) {
    num_thread = 1;
    it_max = atoi(argv[2]);
  } else {
    throw std::runtime_error("Usage: " + std::string(argv[0]) + " <XCLBIN File> <iterations>");
  }

  std::string xclbinFileName = argv[1];
  auto device = xrt::device(0);

  std::vector<std::thread> threads;
  for (int i = 0; i < num_thread; i++)
    threads.emplace_back(std::thread(run_test_iterations, xclbinFileName, std::ref(device), i, it_max));

  for (auto& th : threads)
    th.join();
}

int
main(int argc, char **argv)
{
  try {
    run(argc, argv);
    std::cout << "TEST PASSED!\n";
    return EXIT_SUCCESS;
  } catch (const std::exception& ex) {
    std::cout << ex.what() << '\n';
  }

  return EXIT_FAILURE;
}
