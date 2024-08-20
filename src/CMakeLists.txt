# SPDX-License-Identifier: Apache-2.0
# Copyright (C) 2023 Advanced Micro Devices, Inc. All rights reserved.
cmake_minimum_required(VERSION 3.0)
cmake_policy(SET CMP0057 NEW)

project(vtd VERSION 1.0.0)

# This is required by XRT
set(CMAKE_CXX_STANDARD 17)

# Turn this ON if you want to see verbose prints during build
set(CMAKE_VERBOSE_MAKEFILE OFF)

# All these tests depend on XRT
# All Executables will need to link xrt_coreutil library
# Cmake will search for it in the system
find_package(XRT REQUIRED)

# Since all of our executables will be built the same way
# We can define a cmake function to build the executables
function(build_testcase sources require_thread workdirs)
  set(ALLOWED_DRIVERS "wdf, mcdm, lnx")
  set(SUPPORTED 0)

  get_filename_component(testdir ${CMAKE_CURRENT_SOURCE_DIR} NAME)
  if (DEFINED target_to_build)
      set(target "${target_to_build}")
      unset(target_to_build)
  else()
      set(target "${testdir}_test")
  endif()
  set(snltestname "${target}_snl")

  if ( ${target} MATCHES "lib.*")
    add_library(${target} SHARED ${sources})
  else ()
    add_executable(
      ${target}
      ${sources}
      )
  endif()
  target_include_directories(
    ${target}
    PRIVATE
    ${XRT_INCLUDE_DIRS}
    ${PROJECT_SOURCE_DIR}/common/include
    ${PROJECT_SOURCE_DIR}/common
    )
  
  target_link_libraries(
    ${target}
    PRIVATE
    XRT::xrt_coreutil
    )

  if(MSVC)
    target_compile_options(
      ${target}
      PRIVATE
      "/Zc:__cplusplus"
      )
  endif()

  # phread or equivalent is required to build hw_ctx_multi_thd
  set(NEED_THREAD ${require_thread})
  if (NEED_THREAD STREQUAL "yes")
    set(THREADS_PREFER_PTHREAD_FLAG ON)
    find_package(Threads REQUIRED)
    target_link_libraries(${target} PRIVATE ${CMAKE_THREAD_LIBS_INIT})
  endif()

endfunction()


set(sources
  ${CMAKE_CURRENT_SOURCE_DIR}/src/tct_tp.cpp
)
set(NEED_THREAD no)
set(WORKDIRS workspace)

build_testcase(${sources} ${NEED_THREAD} "${WORKDIRS}")