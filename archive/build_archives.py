#!/usr/bin/env python3

import subprocess
import argparse
import shutil
from pathlib import Path

def check_ar_utility():
    if not shutil.which('ar'):
        print("Error: 'ar' utility not found. Please install binutils package.")
        exit(1)

def get_archive_contents(archive_path):
    if not archive_path.exists():
        return set()
    result = subprocess.run(['ar', 't', str(archive_path)], capture_output=True, text=True)
    return set(f.strip() for f in result.stdout.strip().split('\n') if f.strip()) if result.returncode == 0 else set()

def create_archive(folder_path):
    if not folder_path.exists():
        print(f"Error: Folder {folder_path} does not exist")
        return False, [], []
    
    # Get all files recursively from the folder and its subdirectories, excluding .a files
    files = list(folder_path.rglob('*'))
    files = [f for f in files if f.is_file() and f.suffix != '.a']
    
    if not files:
        print(f"Error: Folder {folder_path} has no files")
        return False, [], []
    
    output_name = f"xrt_smi_{folder_path.name}.a"
    output_path = folder_path / output_name  # Store archive inside the folder itself
    old_files, archive_existed = get_archive_contents(output_path), output_path.exists()
    
    print(f"{'Updating' if archive_existed else 'Creating'} {output_name} from {len(files)} files...")
    
    file_paths = [str(f.absolute()) for f in files]
    
    if archive_existed:
        # Check which files are newer than the archive before updating
        archive_mtime = output_path.stat().st_mtime
        updated_files = [f.name for f in files if f.name in old_files and f.stat().st_mtime > archive_mtime]
        
        # Use 'ar u' (update) to only add files newer than those in archive
        result = subprocess.run(['ar', 'rus', str(output_path)] + file_paths, 
                              capture_output=True, text=True)
        action = "Updated"
    else:
        updated_files = []
        # Create new archive
        result = subprocess.run(['ar', 'rcs', str(output_path)] + file_paths, 
                              capture_output=True, text=True)
        action = "Created"
    
    if result.returncode != 0:
        print(f"✗ Failed: {result.stderr}")
        return False, [], []
    
    print(f"✓ {action}: {output_path}")
    
    # Show what actually changed by comparing before/after
    new_files_set = get_archive_contents(output_path)
    added = new_files_set - old_files
    removed = old_files - new_files_set
    
    if archive_existed:
        for files_list, symbol, label, emoji in [
            (added, "+", "New files added", "➕"),
            (removed, "-", "Files removed", "➖"), 
            (updated_files, "~", "Files updated", "🔄")
        ]:
            if files_list:
                print(f"  {emoji} {label} ({len(files_list)}):")
                [print(f"    {symbol} {file}") for file in sorted(files_list)]
        
        if not added and not removed and not updated_files:
            print(f"  📄 No changes detected")
        
        return True, list(added), updated_files
    else:
        print(f"  📦 Files added to new archive ({len(new_files_set)}):")
        [print(f"    + {file}") for file in sorted(new_files_set)]
        return True, list(new_files_set), []

def print_help():
    print("""Archive Builder - Create .a archives from folders

USAGE: python build_archives.py [folders...]
ARGUMENTS: folders - List of folder names (default: all folders in current directory)

EXAMPLES:
    python build_archives.py          # Create archives for all folders
    python build_archives.py phx      # Create archive for specific folder
    python build_archives.py phx ve2  # Create archives for multiple folders

OUTPUT: Archives created as xrt_smi_<foldername>.a""")

def main():
    check_ar_utility()
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument('-h', '--help', action='store_true')
    parser.add_argument('folders', nargs='*', help='Folder names to create archives for')
    args = parser.parse_args()
    
    if args.help:
        print_help()
        return 0
    
    current_dir = Path(".")
    folder_names = args.folders or [d.name for d in current_dir.iterdir() if d.is_dir()]
    if not args.folders:
        print(f"No folders specified, processing all: {', '.join(folder_names)}")
    
    folders = [current_dir / name for name in folder_names if (current_dir / name).exists()]
    [print(f"Warning: Folder {name} not found, skipping") for name in folder_names if not (current_dir / name).exists()]
    
    if not folders:
        print("No valid folders found")
        return 1
    
    print(f"Processing {len(folders)} folder(s)...")
    success, total_new, total_updated, archives_info = 0, 0, 0, []
    
    for folder in folders:
        success_status, new_files, updated_files = create_archive(folder)
        if success_status:
            success += 1
            total_new += len(new_files)
            total_updated += len(updated_files)
            archives_info.append((f"xrt_smi_{folder.name}.a", new_files, updated_files))
        print()
    
    print("=" * 60)
    print(f"SUMMARY:\nArchives processed: {success}/{len(folders)}\nTotal new files: {total_new}\nTotal updated files: {total_updated}")
    
    if archives_info:
        print("\nArchive changes:")
        for archive_name, new_files, updated_files in archives_info:
            status = [f"{len(new_files)} new"] if new_files else []
            status += [f"{len(updated_files)} updated"] if updated_files else []
            print(f"  {archive_name}: {', '.join(status) or 'no changes'}")
    
    return 0 if success == len(folders) else 1

if __name__ == "__main__":
    exit(main())