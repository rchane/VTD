# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2023 Advanced Micro Devices, Inc. All rights reserved.

APP			= df_bw

HOST_SRCS	+= src/$(APP).cpp

# Host compiler global settings
INCS		+= -I$(XILINX_XRT)/include
CXXFLAGS	+= -Wall -O0 -g -std=c++14 -fmessage-length=0
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
