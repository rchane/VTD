# Runner Directory Archive Creation Guide

This directory contains test runners and benchmarks for different NPU platforms: `npu3`, `phx`, and `strx`. Each platform has its own subdirectory with specific test configurations and binaries.

## Directory Structure

```
runner/
├── npu3/           # NPU3 platform tests
├── phx/            # Phoenix platform tests
└── strx/           # Strix platform tests
```

## Creating Archives

Use the `ar` utility to create archives. **Note**: The `ar` utility preserves directory paths by default and does NOT automatically flatten file structure.

### Platform Archives

```bash
# Archive all NPU3 subdirectories
(cd npu3 && find . -type f -print0 | xargs -0 ar -cr xrt_smi_npu3.a)

# Archive all PHX subdirectories  
(cd phx && find . -type f -print0 | xargs -0 ar -cr xrt_smi_phx.a)

# Archive all STRX subdirectories
(cd strx && find . -type f -print0 | xargs -0 ar -cr xrt_smi_strx.a)
```

## File Types in Archives

Each test category typically contains:
- **ELF files** (`.elf`): Executable binaries for the NPU
- **JSON files** (`.json`): Configuration profiles and recipes
- **XCLBIN files** (`.xclbin`): FPGA bitstream files
- **Archive files** (`.a`): Static library files (XRT SMI)

## Archive Command Options

- `c`: Create archive
- `r`: Insert files (replace if already exists)
- The `ar` utility creates archives with all files flattened at the root level

## Notes

- Archives are created in the current working directory
- Use `ar -t archive_name.a` to list contents of an archive
- Use `ar -x archive_name.a` to extract all files from an archive
- All files will be extracted to the current directory without preserving subdirectory structure