# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.

APP			= preempt

HOST_SRCS	+= $(APP).cpp

# Host compiler global settings
INCS		+= -I$(XILINX_XRT)/include
CXXFLAGS	+= -Wall -O0 -g -std=c++17 -fmessage-length=0
LDFLAGS		+= -lrt -lstdc++ -lpthread -L$(XILINX_XRT)/lib -lxrt_coreutil

all: $(APP).exe

# Building Host
$(APP).exe: $(HOST_SRCS)
	$(CXX) $(CXXFLAGS) $^ $(INCS) $(LDFLAGS) -o $@

run: $(APP).exe
	./$< $(XCLBIN) $(ITR)

.PHONY: clean
clean:
	rm -f $(APP).exe
