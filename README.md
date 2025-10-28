# Linux Recycle Bin System
## Authors
Diogo Ferreira Martins
98501
Hélio Filho
93390

---

## Description
This project implements a **Recycle Bin system for Linux environments** using Bash scripting.  
It replicates key features of the Windows Recycle Bin, allowing users to safely delete, restore, and permanently remove files, while maintaining metadata and configurable system settings.

The system uses a modular structure, with each operation handled by a dedicated shell function. Metadata is stored in a CSV database, and all actions are logged for tracking and troubleshooting.

---

## Installation
1. Clone or download the project files to your system.
2. Give execution permission to the main script:
   ```bash
   chmod +x recycle_bin.sh
3. Run the script for the first time to initialize the recycle bin environment:
   ./recycle_bin.sh init

This creates:

~/.recycle_bin/ main directory

~/.recycle_bin/files/ for deleted items

~/.recycle_bin/metadata.db for file metadata

~/.recycle_bin/config configuration file

~/.recycle_bin/recyclebin.log log file

---

## Usage
[How to use with examples]

Each operation is executed through the main script recycle_bin.sh.

1. Delete file(s)

Moves one or more files or directories to the recycle bin.
./recycle_bin.sh delete <file1> <file2> ...


2. List contents

Displays all items currently in the recycle bin (basic mode).
./recycle_bin.sh list

3. List contents (detailed mode)
./recycle_bin.sh list --detailed


4. Restore file

Restores a deleted file to its original location (by ID or filename).
./recycle_bin.sh restore <file_id or filename>


5. Help

Shows usage instructions and a summary of all available commands.
./recycle_bin.sh help


---

## Features
- [List of implemented features]
- [Mark optional features]

Modular design (each action handled by its own function)

Safe deletion system — files are moved, not permanently erased

Metadata tracking (stored in metadata.db)

Recycle bin listing with formatted table output

Detailed view for full metadata inspection (--detailed)

File restoration:

Restores files to their original path

Recreates missing directories automatically

Handles naming conflicts (overwrite, rename, or cancel)

Restores original file permissions and ownership

Logging system for every action (recyclebin.log)

Basic error handling (invalid options, missing files, permission issues, etc.)

---

## Configuration
[How to configure settings]

---

## Examples
[Detailed usage examples with screenshots]

---

## Known Issues
[Any limitations or bugs]

---

## References
[Resources used]
