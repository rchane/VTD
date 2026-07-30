# Archive Directory - NPU Platform Test Archives

This directory contains test runners and benchmarks for different NPU platforms: `npu3`, `phx`, `strx`, and `ve2`. Each platform has its own subdirectory with specific test configurations and binaries.

## Directory Structure

```
archive/
├── npu3/                    # NPU3 platform tests
│   └── xrt_smi_npu3.a      # Generated archive
├── phx/                     # Phoenix platform tests  
│   └── xrt_smi_phx.a       # Generated archive
├── strx/                    # Strix platform tests
│   └── xrt_smi_strx.a      # Generated archive
├── ve2/                     # Telluride platform tests
│   ├── t50/
│   │   └── xrt_smi_ve2.a   # Generated archive (t50)
│   └── t20/
│       └── xrt_smi_ve2.a   # Generated archive (t20)
└── build_archives.py       # Archive creation script
```

## Creating Archives (Recommended)

Use the provided Python script for automated archive creation:

### Basic Usage

One or more platform folder names are **required**. Allowed platform values: `phx`, `strx`, `npu3`, `ve2`.

For `ve2`, an optional variant argument selects the Telluride silicon target: `t50` or `t20`. If `ve2` is given without a variant, **`t50` is used by default**.

```bash
# Create archive for a single platform
python build_archives.py strx

# Create archives for multiple platforms
python build_archives.py phx strx npu3

# Create VE2 archive for T50 (default when variant is omitted)
python build_archives.py ve2
python build_archives.py ve2 t50

# Create VE2 archive for T20
python build_archives.py ve2 t20
```

Running without folder arguments fails with a usage error. Unknown or path-traversal folder names (e.g. `../../other`) are refused; only the four platform directories under `archive/` are accepted. Variant names (`t50`, `t20`) are only valid alongside `ve2`.

### VE2 Archives

| Command | Archive output |
|---------|----------------|
| `python build_archives.py ve2` | `ve2/t50/xrt_smi_ve2.a` |
| `python build_archives.py ve2 t50` | `ve2/t50/xrt_smi_ve2.a` |
| `python build_archives.py ve2 t20` | `ve2/t20/xrt_smi_ve2.a` |

### Script Features

- **Required platform argument**: At least one of `phx`, `strx`, `npu3`, or `ve2` must be specified
- **VE2 variant argument**: Optional `t50` or `t20` after `ve2`; defaults to `t50`
- **Path safety**: Resolves folders only under this `archive/` directory; rejects other paths
- **Recursive file collection**: Automatically includes files from subdirectories
- **Flattened structure**: Creates archives with all files at root level
- **Smart updates**: Only updates files newer than existing archive
- **Change tracking**: Shows added, removed, and updated files
- **Automatic exclusion**: Skips `.a` files to prevent self-inclusion

### Example Output

```
Processing 1 folder(s)...
Updating xrt_smi_strx.a from 25 files...
✓ Updated: strx/xrt_smi_strx.a
  ➕ New files added (2):
    + firmware_log.json
    + trace_events.json
  🔄 Files updated (3):
    ~ config.json
    ~ nop.elf
    ~ validate.xclbin

SUMMARY:
Archives processed: 1/1
Total new files: 2
Total updated files: 3
```

## Manual Archive Creation (Alternative)

If you need to create archives manually without the script:

```bash
# Archive all STRX subdirectories manually
(cd strx && find . -type f ! -name "*.a" -print0 | xargs -0 ar -cr xrt_smi_strx.a)

# Archive all PHX subdirectories manually  
(cd phx && find . -type f ! -name "*.a" -print0 | xargs -0 ar -cr xrt_smi_phx.a)

# VE2 archives
python build_archives.py ve2 t50
python build_archives.py ve2 t20
```

## File Types in Archives

Each platform directory typically contains:
- **ELF files** (`.elf`): Executable binaries for the NPU
- **JSON files** (`.json`): Configuration profiles, recipes, and firmware logs
- **XCLBIN files** (`.xclbin`): FPGA bitstream files
- **Other test files**: Various test configurations and data

## Archive Management

```bash
# List contents of an archive
ar -t strx/xrt_smi_strx.a

# Extract all files from an archive
ar -x strx/xrt_smi_strx.a

# Get help for the Python script
python build_archives.py --help
```

## Notes

- Run `build_archives.py` from any working directory; it always targets platform subdirs under `archive/`
- Archives are stored in their respective platform directories (e.g., `strx/xrt_smi_strx.a`, `ve2/t50/xrt_smi_ve2.a`)
- All files are flattened to root level in archives (no directory structure preserved)
- The Python script automatically excludes existing `.a` files to prevent circular inclusion
- Use the Python script for consistent and automated archive management
