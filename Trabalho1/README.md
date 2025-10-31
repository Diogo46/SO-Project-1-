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

To delete a file name that has spaces in its name, simple put the file name inside "".
./recycle_bin.sh delete "as marias.txt"

The action is properly logged as follows: 2025-10-29 18:34:47 [DELETE] Deleted 'aaa.txt' (ID: 1761762887_z1PKwdCSoS).




2. List contents

Displays all items currently in the recycle bin (normal mode), showing us ID, Name, Deleted At and Size.
./recycle_bin.sh list

If the recyble bin is empty and you try to list it, it will return "Recycle bin is empty". 




3. List contents (detailed mode)

Use the --detailed flag after list or/and --sort
./recycle_bin.sh list --detailed --sort=name|date|size

There are two extra modes we can use: detailed mode (--detailed) and sort mode (--sort)
Detailed mode shows, beyond what we already see on the normal mode, path, type, perms and owner.
All of the files in the recycle in can now be sorted using sort. The user is able to sort from date and size (descendent order) and name (A to Z and case insensitive). 

./recycle_bin.sh list --sort=size
./recycle_bin.sh list --sort=date
./recycle_bin.sh list --sort=name

You can also use --reverse or -r flag to revert sort order (oldest first instead of newest first, smallest first instead of biggest first)

./recycle_bin.sh list --sort=size --reverse (or -r)
./recycle_bin.sh list --sort=date --reverse (or -r)

Naturally, you can still add the --detailed to have a detailed, sorted (or reverse sorted) list. 

There are two main validation steps throughout the function's usage: 
- if you try to run a flag that's not --detailed, --sort, --reverse or -r, you will get an error message and then it will show you what the valid options are;
- if you try to sort by anything other than size, name or date, you will get the same message and a list of sorting options;

If the recyble bin is empty and you try to list it, it will return "Recycle bin is empty". 




4. Restore file

Restores a deleted file to its original location (by ID or filename).
./recycle_bin.sh restore <file_id or filename>

When restoring by filename, if there are two or more files with the same name, the user will be prompted via a menu to select which file he wants. Supports both versions. The first argument will always be read as a name, unless you use --id to make it an ID, making it for intuitive to use.
./recycle_bin.sh restore 12345_abcd
./recycle_bin.sh restore --pattern=report


The actions is properly logged as follows: 2025-10-29 18:11:40 [RESTORE] Restored 'test.txt' to './test.txt'



5. Help

Shows usage instructions and a summary of all available commands.
./recycle_bin.sh help





6. Empty recycle bin

With all the following calls, you will always be prompted to confirm if you want to delete the said items, since all changes are permanent.

Empties the entire recycle bin.
./recycle_bin.sh empty

Permanently deletes a file by ID.
./recycle_bin.sh empty 1761655417_kf89js

Permanently deletes a file by pattern/name (case insensitive).
./recycle_bin.sh empty --pattern=aa
./recycle_bin.sh empty --pattern=test

After deleting a file (or multiple) from the recycle bin, you will be shown a list of deleted items and another information of how many items you deleted and size. 

The action is properly logged as follows: 2025-10-28 20:22:21 [EMPTY] Deleted 'as marias.txt' (ID: 1761681451_vuiawn).

The metadata log is also appropriately updated to reflect all changes.






7. Search function

Searches in the recycle bin for files you want to find, according to your criteria.
./recycle_bin.sh search

When running just search, you will be met with a "No search criteria provided". 
./recycle_bin.sh search

To search by filename pattern, you should run the code below. You will then be provided with all files who have "name" in their name. 
./recycle_bin.sh search name

To search by date range, you should run the code below. You can set your range to have a from date and a to date, or you can search only from date and only from to date. The ranges are both single ended. The date should be in the YYYY-MM-DD format. Date ranges are inclusive: initial and end dates are included in the search.
./recycle_bin.sh search --date-from=2025-10-27 --date-to=2025-10-30
./recycle_bin.sh search --date-from=2025-10-27
./recycle_bin.sh search --date-to=2025-10-30

If there are no files on your date criteria you will be met with a "No matching items found in this date range". 
./recycle_bin.sh search --date-from=2025-10-29 --date-to=2025-10-30

You can also use the --detailed mode while in search, for a detailed look into the files you're searching. 
./recycle_bin.sh search test --detailed

Everytime the function is used, it's logged in the following manner:
2025-10-28 20:45:58 [SEARCH] Search criteria: name='test' date_from=''(none)'' date_to=''(none)'' -- returned 3 items




8. Version command

Show version and important file paths.
./recycle_bin.sh version



9. Configuration command

This command allows user to configurate the maximum size of the recycle bin and the maximum number of retention days.
./recycle_bin.sh config 

To show current configuration, use:
./recycle_bin.sh config show

To change current quota and update maximum allowed recycle bin size, use:
Example: ./recycle_bin.sh config set quota (size)

To change current retention days (maximum number of days a file can be in the recycle bin before a cleanup):
Example: ./recycle_bin.sh config set retention (days)



10. Cleanup/Autoclean

Manually triggers auto-cleanup of expired items (older than RETENTION_DAYS).
./recycle_bin.sh cleanup

Before actually deleting the items, you can use a dry run to see what files would be deleted:
./recycle_bin.sh cleanup --dry-run


11. Preview

Shows a quick preview of a recycled file (first ten lines):
./recycle_bin.sh preview

Example: ./recycle_bin.sh preview <ID>



12. Stats

Shows detailed statistics about recycle bin usage: 
./recycle_bin.sh stats

Example: ./recycle_bin.sh stats



13. Interactive menu mode

You can manage the recycle bin interactively through a simple menu system. To launch it, use either:
 ./recycle_bin.sh interactive

 or 

 ./recycle_bin.sh menu

Inside the menu, you can use any and all functions mentioned above, interactively. 



14. Debug mode

Implemented several debug lines on all major functions and processes. Activate it by using any function and then using the --verbose flag:
Example: ./recycle_bin list --verbose


---

## Features
- [List of implemented features]
- [Mark optional features]

Modular design (each action handled by its own function)

Safe deletion system — files are moved, not permanently erased

Metadata tracking (stored in metadata.db)

Recycle bin listing with formatted table output

Detailed view for full metadata inspection (--detailed)



- generate_unique_id

Adapted the function to enforce safe character set [A-Za-z0-9_-] (shell-friendly) and a fallback to never emit an empty ID; [OPTIONAL]




- version_command() [OPTIONAL]

Created a version command function to print the current version and basic environmental information; [OPTIONAL]



- config_command() [OPTIONAL]

Created a configuration command to show and update current configuration (maximum size and retention days); [OPTIONAL]




- delete_file()

Accept single or multiple file paths as arguments;

Preserve original file metadata (timestamp, permissions, owner);

Store original absolute path for restoration;

Generate unique identifiers to prevent name conflicts;

Support both files and directories (recursive);

Create timestamped entries in metadata log;




- list_recycled()

Shows original filename and path;

Display deletion date and time;

Show file size;

Provide a unique identifier for each item;

Support formatted output (table view);

Implement sorting options (by date, name, size);

Created a --reverse or -r flag for reverse sorting order; [OPTIONAL]

Can always use detailed option, even when sorting the list; [OPTIONAL]

Added safeguards for misinputs; [OPTIONAL]


- restore_file()

Restores files to their original path;

Recreates missing directories automatically;

Handles naming conflicts (overwrite, rename, or cancel);

Restores original file permissions and ownership;

Logging system for every action (recyclebin.log);

Basic error handling (invalid options, missing fi;les, permission issues, etc.);






- empty_recyclebin()

Delete all items permanently;

Support selective deletion by ID or pattern;

Require confirmation before execution;

Update metadata log appropriately;

Provide summary of deleted items;





- search_recycled()

Search by filename pattern;

Search by date range;

Search by file type/extension;

Display matching results with full details;



- interactive_menu()

Created an interactive menu to use any all functions above, interactively; 




- display_help()

Updated the help function to show all available information about all the executable commands and prompts in this script;



- show_statistics() [OPTIONAL]

Created a statistics function to show basic stats about the recycle bin, including storage usage, item breakdown and timeline; [OPTIONAL]





- auto_cleanup() [OPTIONAL]
 
Created a auto-cleanup function to eliminate files older than the configured max number of retention days; [OPTIONAL]

Created a dry run, to see what files would be deleted before actually deleting them; [OPTIONAL]




- preview_file() [OPTIONAL]

Created a preview file function, to preview the first ten lines or the type of file in the recycle bin; [OPTIONAL]




- debug() 

Implemented several debug lines over all major functions to run with verbose mode;



---

## Configuration

Using the config_command() function, the user can input the configuration it wishes for the recycle bin.

With the code below, you can see the current configuration parameters. 
./recycle_bin.sh config show

To change the maximum size, you can run the following code and insert the maximum size in MB as the last argument.
./recycle_bin.sh config set quota 2048

To change the number of retention days, you can run the following code and insert the number of retentions days.
./recycle_bin.sh config set retention 45

---

## Examples

All examples are listed below the function's explanation in Usage. Inside the screenshot folder, you can also find several screenshots of the aforementioned functions working.

---

## Known Issues

The script was developed for Bash and uses features like [[ ... ]], case, and process substitution, so it may not run correctly in sh, zsh, or dash.
Filenames containing commas or newlines can break the CSV structure of metadata.db.
Files are restored using chmod and stored owner info, but original ownership cannot be restored unless the user has root privileges. 

---

## References

GNU Awk User’s Guide - https://www.gnu.org/software/gawk/manual/ (Last consulted at 31-10-2025);
GNU Bash Manual - https://www.gnu.org/software/bash/manual/ (Last consulted at 31-10-2025);
Stack Overflow; 
Reddit Linux and bash programming subs;
Linux Man Pages;
