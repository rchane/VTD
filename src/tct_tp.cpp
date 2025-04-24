// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.

/* This host application measures the average TCT latency and TCT throughput 
 * for single column and all columns tests.
 * The DPU sequence loopback the small chunk of input data from DDR through 
 * a AIE MM2S Shim DMA channel back to DDR through a S2MM Shim DMA channel.
 * TCT is used for dma transfer completion. Host app measures the time for
 * predefined number of Tokens and calculate the latency and throughput.
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

constexpr int dpu_instr_str_len = 8;
constexpr int host_app = 1;
constexpr int tnx_len = 4;
constexpr int tnx_word_count = tnx_len / 4;

//Number of Sample Tokens to measure the throughtput
int samples = 10000;


/* Copy values from text file into buff, expecting values are ASCII encoded
 * 4-Byte hexadecimal values.
 */
void
init_instr_buf(const std::string &file_name, xrt::bo &bo_instr)
{
  auto instr = bo_instr.map<int*>();
  std::string line;
  std::ifstream ifs(file_name);

  if (!ifs.is_open())
    throw std::runtime_error("Error: Failure opening file " + file_name + " for reading!!\n");

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
get_instr_size(const std::string &fname)
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
run_test_iterations(const std::string &xclbinFileName, const std::string &dpuSequenceFileName, xrt::device &device, int tid)
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

  size_t instr_size = get_instr_size(dpuSequenceFileName);

  auto instr = xrt::bo(device, instr_size * sizeof(int), XCL_BO_FLAGS_CACHEABLE, dpu.group_id(5));
  auto in = xrt::bo(device, tnx_len, XRT_BO_FLAGS_HOST_ONLY, dpu.group_id(1));
  auto out = xrt::bo(device, 4*tnx_len, XRT_BO_FLAGS_HOST_ONLY, dpu.group_id(3));

  init_instr_buf(dpuSequenceFileName, instr);

  instr.sync(XCL_BO_SYNC_BO_TO_DEVICE);
  auto in_mapped = in.map<int*>();
  for (int i = 0; i < tnx_word_count; i++)
  in_mapped[i] = rand() % 4096;
  in.sync(XCL_BO_SYNC_BO_TO_DEVICE);

  auto start = std::chrono::high_resolution_clock::now();
  auto run = dpu(host_app, in, NULL, out, NULL, instr, instr_size, NULL);
  run.wait2();
  auto end = std::chrono::high_resolution_clock::now();

  out.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
  auto out_mapped = out.map<int*>();
  for (int i = 0; i < tnx_word_count; i++) {
    if (out_mapped[i] == in_mapped[i])
      continue;
    std::runtime_error("Error: Output data mismatch!\nTEST FAILED!\n");
  }

  long long elapsedMicroSecs = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
  std::cout << "Average Time for TCT (us): " << elapsedMicroSecs/(float)samples << std::endl;
  std::cout << "Average TCT/s: " << samples * (1000000/(float)elapsedMicroSecs) << std::endl;
  
}

void
run(int argc, char **argv)
{
  int num_thread;

  // Set the number of threads and iterations
  // Default: 1 thread, 1 iteration
  if (argc == 4) {
    num_thread = 1;
  } else {
    throw std::runtime_error("Usage: " + std::string(argv[0]) + " <XCLBIN File> <DPU Sequence File> <BDF of IPU device>\n");
  }
  std::string xclbinFileName = argv[1];
  std::string dpuSequenceFileName = argv[2];
  std::string index = argv[3];

  if (strstr(argv[2], "4col")) {
      samples = 20000;
  }
  
  auto device = xrt::device(index);
  
  std::vector<std::thread> threads;
  for (int i = 0; i < num_thread; i++)
    threads.emplace_back(std::thread(run_test_iterations, xclbinFileName, dpuSequenceFileName, std::ref(device), i));

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
