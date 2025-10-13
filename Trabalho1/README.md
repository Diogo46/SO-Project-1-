# Linux Recycle Bin System
## Authors
Diogo Ferreira Martins
98501
Hélio Filho
96758

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

---

## Features
- [List of implemented features]
- [Mark optional features]

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
