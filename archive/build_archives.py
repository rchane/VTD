#!/usr/bin/env python3

import subprocess
import argparse
import shutil
from pathlib import Path

ALLOWED = {"phx", "strx", "npu3", "ve2"}
VE2_VARIANTS = {"t10", "t20", "t50"}
VE2_COMMON = (
    "cmd_chain_latency",
    "cmd_chain_throughput",
    "df_bandwidth",
    "latency",
    "throughput",
)


def check_ar_utility():
    if not shutil.which('ar'):
        print("Error: 'ar' utility not found. Please install binutils package.")
        exit(1)


def get_archive_contents(archive_path):
    if not archive_path.exists():
        return set()
    result = subprocess.run(['ar', 't', str(archive_path)], capture_output=True, text=True)
    return set(f.strip() for f in result.stdout.strip().split('\n') if f.strip()) if result.returncode == 0 else set()


def pack_archive(files, output_path, label):
    if not files:
        print(f"Error: No files to pack for {label}")
        return False, [], []

    old_files, archive_existed = get_archive_contents(output_path), output_path.exists()
    print(f"{'Updating' if archive_existed else 'Creating'} {output_path.name} ({label}) from {len(files)} files...")

    file_paths = [str(f.resolve()) for f in files]
    new_names = {f.name for f in files}

    if archive_existed and old_files - new_names:
        output_path.unlink()
        archive_existed = False
        old_files = set()

    if archive_existed:
        archive_mtime = output_path.stat().st_mtime
        updated_files = [f.name for f in files if f.name in old_files and f.stat().st_mtime > archive_mtime]
        result = subprocess.run(['ar', 'rus', str(output_path)] + file_paths, capture_output=True, text=True)
        action = "Updated"
    else:
        updated_files = []
        result = subprocess.run(['ar', 'rcs', str(output_path)] + file_paths, capture_output=True, text=True)
        action = "Created"

    if result.returncode != 0:
        print(f"✗ Failed: {result.stderr}")
        return False, [], []

    print(f"✓ {action}: {output_path}")
    new_files_set = get_archive_contents(output_path)
    added = new_files_set - old_files
    removed = old_files - new_files_set

    if archive_existed:
        for files_list, symbol, label_text, emoji in [
            (added, "+", "New files added", "➕"),
            (removed, "-", "Files removed", "➖"),
            (updated_files, "~", "Files updated", "🔄"),
        ]:
            if files_list:
                print(f"  {emoji} {label_text} ({len(files_list)}):")
                [print(f"    {symbol} {file}") for file in sorted(files_list)]
        if not added and not removed and not updated_files:
            print("  📄 No changes detected")
        return True, list(added), updated_files

    print(f"  📦 Files added to new archive ({len(new_files_set)}):")
    [print(f"    + {file}") for file in sorted(new_files_set)]
    return True, list(new_files_set), []


def archive_files(root):
    return [f for f in root.rglob('*') if f.is_file() and f.suffix != '.a']


def add_tree(members, root, skip=None):
    skip = skip or set()
    for path in archive_files(root):
        if skip and any(path.is_relative_to(s) for s in skip):
            continue
        members[path.name] = path


def collect_ve2_files(ve2_root, variant):
    members = {}
    variant_dir = ve2_root / variant
    elves = variant_dir / "elves"
    skip = {elves} if elves.is_dir() else set()

    for name in VE2_COMMON:
        add_tree(members, ve2_root / name, skip)

    if variant == "t50":
        add_tree(members, variant_dir, skip)

    add_tree(members, elves, skip)
    return list(members.values())


def create_archive(folder_path):
    if not folder_path.exists():
        print(f"Error: Folder {folder_path} does not exist")
        return False, [], []

    files = archive_files(folder_path)
    if not files:
        print(f"Error: Folder {folder_path} has no files")
        return False, [], []

    output_path = folder_path / f"xrt_smi_{folder_path.name}.a"
    return pack_archive(files, output_path, folder_path.name)


def create_ve2_archive(ve2_root, variant):
    variant_dir = ve2_root / variant
    if not variant_dir.is_dir():
        print(f"Error: Folder {variant_dir} does not exist")
        return False, [], []

    files = collect_ve2_files(ve2_root, variant)
    return pack_archive(files, variant_dir / "xrt_smi_ve2.a", f"ve2/{variant}")


def print_help():
    print("""Archive Builder - Create .a archives from folders

USAGE: python build_archives.py <folder> [folder...] [t10|t20|t50]
ARGUMENTS: folder - Platform folder names (phx, strx, npu3, ve2)

EXAMPLES:
    python build_archives.py phx
    python build_archives.py ve2 t50
    python build_archives.py ve2 t10
    python build_archives.py ve2 t20

OUTPUT:
  phx/strx/npu3 -> xrt_smi_<foldername>.a inside each platform folder
  ve2 t10/t20/t50 -> xrt_smi_ve2.a inside ve2/<variant>/""")


def main():
    check_ar_utility()
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('-h', '--help', action='store_true')
    parser.add_argument('folders', nargs='+', help='Platform folder names (phx, strx, npu3, ve2)')
    args = parser.parse_args()

    if args.help:
        print_help()
        return 0

    archive_root = Path(__file__).resolve().parent
    ve2_variants = [name for name in args.folders if name in VE2_VARIANTS]
    folder_names = [name for name in args.folders if name not in VE2_VARIANTS]

    folders = []
    for name in folder_names:
        cand = (archive_root / name).resolve()
        if name not in ALLOWED or not cand.is_relative_to(archive_root) or not cand.is_dir():
            print(f"Warning: refusing folder '{name}' (not an allowed platform dir)")
            continue
        folders.append(cand)

    if not folders:
        print("No valid folders found")
        return 1

    print(f"Processing {len(folders)} folder(s)...")
    success, total_new, total_updated, archives_info = 0, 0, 0, []

    for folder in folders:
        if folder.name == "ve2":
            variants = ve2_variants or ["t50"]
            variant_ok = 0
            for variant in variants:
                if variant not in VE2_VARIANTS:
                    print(f"Warning: refusing VE2 variant '{variant}'")
                    continue
                ok, new_files, updated_files = create_ve2_archive(folder, variant)
                if ok:
                    variant_ok += 1
                    total_new += len(new_files)
                    total_updated += len(updated_files)
                    archives_info.append((f"ve2/{variant}/xrt_smi_ve2.a", new_files, updated_files))
                print()
            success += 1 if variant_ok == len(variants) else 0
            continue

        ok, new_files, updated_files = create_archive(folder)
        if ok:
            success += 1
            total_new += len(new_files)
            total_updated += len(updated_files)
            archives_info.append((f"xrt_smi_{folder.name}.a", new_files, updated_files))
        print()

    print("=" * 60)
    print(
        f"SUMMARY:\nArchives processed: {success}/{len(folders)}\n"
        f"Total new files: {total_new}\nTotal updated files: {total_updated}"
    )

    if archives_info:
        print("\nArchive changes:")
        for archive_name, new_files, updated_files in archives_info:
            status = [f"{len(new_files)} new"] if new_files else []
            status += [f"{len(updated_files)} updated"] if updated_files else []
            print(f"  {archive_name}: {', '.join(status) or 'no changes'}")

    return 0 if success == len(folders) else 1


if __name__ == "__main__":
    exit(main())
