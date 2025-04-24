<!---SPDX-License-Identifier: Apache-2.0-->
<!---Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.-->

## Copyright updates script
This directory contains configuration files used by the ["Update copyrights headers and disclaimers"](../workflows/copyright_updates.yml) workflow.
- `COPYRIGHT_EXCLUDES` defines "exclusion patterns": Files and directories specified will be excluded from automated copyright updates.
- `languages_config.yml` defines how different file languages should be handled i.e. how to add copyright data without "breaking" the file.

For more details, see the [reusable action used by the workflow and its documentation.](https://gitenterprise.xilinx.com/ACAS-DevOps/actions/tree/main/composite_actions/update_copyright_headers)
