// SPDX-License-Identifier: Apache-2.0
// Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.

#include <cstdlib>
#include <iostream>
#include <sstream>
#include <string>
#include <unistd.h>

// XRT includes
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"
#include "xrt/xrt_hw_context.h"
#include "xrt/xrt_bo.h"
#include "experimental/xrt_elf.h"
#include "experimental/xrt_module.h"
#include "experimental/xrt_ext.h"

constexpr unsigned long int host_app = 3;
static constexpr size_t buffer_size = 20;

double
run_preempt_test(const std::string &xclbinFileName, const std::string &elfFileName, xrt::device &device)
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
  xrt::elf elf(elfFileName);
  xrt::module mod(elf);
  xrt::hw_context context(device, xclbin.get_uuid());

  auto dpu = xrt::ext::kernel(context, mod, kernelName);

  auto bo_ifm = xrt::bo(device, buffer_size, XRT_BO_FLAGS_HOST_ONLY, dpu.group_id(5));
  auto bo_ofm = xrt::bo(device, buffer_size, XRT_BO_FLAGS_HOST_ONLY, dpu.group_id(6));
  auto bo_wts1 = xrt::bo(device, buffer_size, XRT_BO_FLAGS_HOST_ONLY, dpu.group_id(3));
  auto bo_wts2 = xrt::bo(device, buffer_size, XRT_BO_FLAGS_HOST_ONLY, dpu.group_id(4));

  // Set kernel argument and trigger it to run
  auto start = std::chrono::high_resolution_clock::now();
  auto run = dpu(host_app, 0, 0, bo_ifm, bo_ofm, bo_wts1, bo_wts2, 0);
  run.wait2();
  auto end = std::chrono::high_resolution_clock::now();

  double elapsedSecs = std::chrono::duration_cast<std::chrono::microseconds>(end - start).count();
  std::cout << "Time taken: " << elapsedSecs << " us\n";
  return elapsedSecs;
}

void
run(int argc, char **argv)
{
  const int preemptions = 500;
  std::string BDF = argv[1];
  std:: string force_off = "sudo xrt-smi configure --force-preemption disable -d " + BDF;
  std:: string force_on = "sudo xrt-smi configure --force-preemption enable -d " + BDF;

  const unsigned int columns[] = {1, 2, 4};
  for (auto ncol : columns) {
    std::string xclbinFileName = "../xclbin_prod/validate_npu4_elf_4x" + std::to_string(ncol) + ".xclbin";
    std::string elfFileName = "../sequences/preempt_4x" + std::to_string(ncol) + ".elf";
    auto device = xrt::device(0);

    // Make sure force preemption is disabled
    int result = system(force_off.c_str());
    if (result == -1) {
        throw std::runtime_error("Failed to disable force preemtion\n");
    }

    double noop_exec_time = run_preempt_test(xclbinFileName, elfFileName, std::ref(device));

    result = system(force_on.c_str());
    if (result == -1) {
        throw std::runtime_error("Failed to disable force preemtion\n");
    }

    double noop_preempt_exec_time = run_preempt_test(xclbinFileName, elfFileName, std::ref(device));

    result = system(force_off.c_str());
    if (result == -1) {
        throw std::runtime_error("Failed to disable force preemtion\n");
    }

    double overhead = (noop_preempt_exec_time - noop_exec_time) / preemptions;
    std::cout << "Average preemption overhead for 4x" << ncol << " design: " << overhead << "us\n";
  }
}

int
main(int argc, char **argv)
{
  if (argc < 2) {
    std::cerr << "Usage: " << argv[0] << " <BDF>" << std::endl;
    return EXIT_FAILURE;
  }

  try {
    run(argc, argv);
    std::cout << "TEST PASSED!\n";
    return EXIT_SUCCESS;
  } catch (const std::exception& ex) {
    std::cout << ex.what() << '\n';
  }

  return EXIT_FAILURE;
}
