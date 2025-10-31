# Technical Documentation - Linux Recycle Bin System

## 1. Overview
Small shell-based recycle bin that moves files/directories to a dedicated storage area under $HOME/.recycle_bin. Tracks metadata in a simple CSV-like DB and supports delete/list/restore/search/preview/stats/cleanup operations.

Goals:
- Safe soft-deletion (recoverable)
- Simple, portable metadata format
- Configurable retention and quota
- Human-friendly CLI

---

## 2. System architecture (ASCII)
DiogoMartins_HélioFilho_RecycleBin/
|
├── recycle_bin.sh        # CLI and implementation
├── README.md
├── TECHNICAL_DOC.md
├── TESTING.md
├── test_suite.sh
└── screenshots/

Runtime layout:
$HOME/.recycle_bin/
├── files/                 # stored items named by unique ID
├── metadata.db            # CSV header + entries
├── config                 # MAX_SIZE_MB, RETENTION_DAYS
└── recyclebin.log         # operation log

---

## 3. Data flow diagrams (ASCII)

Delete operation:
User 
  ↓
recycle_bin.sh (delete)
  ↓
validate file existence & permissions
  ↓
generate_unique_id()
  ↓
mv file → ~/.recycle_bin/files/<ID>
  ↓
append metadata row → metadata.db
  ↓
log delete action → recyclebin.log
  ↓
(optional) auto_cleanup()


List Operation (list_recycled) 

User 
  ↓
recycle_bin.sh (list)
  ↓
read metadata.db (skip headers)
  ↓
apply sorting (--sort, --reverse)
  ↓
format rows (detailed or compact)
  ↓
display table to user (stdout)


Restore Operation (restore_file)

User 
  ↓
recycle_bin.sh (restore [--id] <pattern>)
  ↓
read metadata.db
  ↓
search by ID or name substring
     ↳ if multiple matches → user selects one
  ↓
mv ~/.recycle_bin/files/<ID> → original_path/original_name
  ↓
chmod perms & remove metadata entry
  ↓
log restore action → recyclebin.log
  ↓
output success message



Search Operation (search_recycled)

User 
  ↓
recycle_bin.sh (search [pattern] [--date-from|--date-to])
  ↓
read metadata.db
  ↓
filter rows by:
     - name substring (case-insensitive)
     - date range (if given)
  ↓
format output (simple or detailed)
  ↓
display results to user



Empty Operation (empty_recyclebin)

User 
  ↓
recycle_bin.sh (empty [ID] [--pattern])
  ↓
load metadata.db entries
  ↓
if ID or pattern → match subset
else → select all
  ↓
confirm (y/N)
  ↓
rm -rf ~/.recycle_bin/files/<matched_IDs>
  ↓
remove entries from metadata.db
  ↓
log deletions → recyclebin.log
  ↓
print summary (count + total size)



Statistics Operation (show_statistics)


User 
  ↓
recycle_bin.sh (stats)
  ↓
read metadata.db
  ↓
count files / dirs / total size
  ↓
read quota & retention from config
  ↓
compute 
  ↓
format summary
  ↓
display to user



Auto Cleanup (auto_cleanup)

User OR delete_file (post-deletion)
  ↓
read retention days from config
  ↓
compute cutoff date (now - RETENTION_DAYS)
  ↓
read metadata.db
  ↓
find entries older than cutoff
  ↓
if --dry-run → list what would be deleted
else:
   rm files + remove metadata entries
   log each deletion
  ↓
print cleanup summary




Preview Operation (preview_file)

User 
  ↓
recycle_bin.sh (preview <ID>)
  ↓
read metadata.db → find entry by ID
  ↓
check file type:
    ├── directory → print notice
    └── file → check mime type
          ├── text → head -n 10
          └── binary → file info + size
  ↓
display preview output



Config Operation (config_command)


User 
  ↓
recycle_bin.sh (config [show|set quota|set retention])
  ↓
if show → read config and display
if set → validate integer
        → sed -i update value
  ↓
confirm update to user


Version Operation (version_command)

User 
  ↓
recycle_bin.sh (version)
  ↓
print version number
  ↓
display key paths:
   - metadata file
   - files directory
   - config file



Help Operation (display_help)

User 
  ↓
recycle_bin.sh (help)
  ↓
read config for current quota/retention
  ↓
print full command reference
  ↓
include interactive menu info + --verbose option
  ↓
exit


Interactive Menu (interactive_menu)

User 
  ↓
recycle_bin.sh (interactive / menu)
  ↓
display numbered options
  ↓
read user choice
  ↓
dispatch corresponding function:
    1 → delete_file
    2 → list_recycled
    3 → restore_file
    4 → search_recycled
    5 → empty_recyclebin
    6 → show_statistics
    7 → auto_cleanup
    8 → preview_file
    9 → config_command show
   10 → config_command set
   11 → display_help
    0 → exit
  ↓
loop until exit



Initialization (initialize_recyclebin)

System OR User (init command)
  ↓
check if ~/.recycle_bin exists
  ↓
if missing:
    mkdir structure:
       ~/.recycle_bin/
       ~/.recycle_bin/files/
    create:
       metadata.db (with headers)
       config (quota + retention)
       recyclebin.log
  ↓
echo success message


Debug Function (debug)

Any function (when --verbose enabled)
  ↓
call debug "<message>"
  ↓
if VERBOSE=true → print yellow [DEBUG] line to stderr
else → no output


---

## 4. Metadata schema explanation
metadata.db (CSV - first two header lines exist in current implementation)

Header row (fields):
- ID: string, generated as "<epoch>_<random6>" (unique file identifier)
- ORIGINAL_NAME: original filename (may contain spaces, stored as CSV field)
- ORIGINAL_PATH: original directory path
- DELETION_DATE: ISO timestamp "YYYY-MM-DD HH:MM:SS"
- FILE_SIZE: integer bytes
- FILE_TYPE: "file" | "directory"
- PERMISSIONS: numeric (e.g., 644)
- OWNER: user:group (string)

Example entry:
1761607543_xpfnr2,document.pdf,/home/user/docs,2025-10-29 14:30:45,234567,file,644,user:group

Notes:
- Rows are appended; the script skips header lines when reading.
- Comparisons on dates work via lexicographic comparison because of ISO format.

---

## 5. Function Descriptions (Short)
-----------------------------

- initialize_recyclebin(): create directories, default config, and metadata header.
- generate_unique_id(): returns epoch_random string used as stored filename.
- delete_file(...): validate, collect stat metadata, move item to files/<ID>, append metadata, log.
- list_recycled(...): read metadata, optional --detailed and --sort modes, pretty-print, compute totals.
- restore_file(<ID|pattern>): find entry (by ID or name), move files/<ID> back to original path, restore perms, remove metadata, log.
- empty_recyclebin([ID|--pattern=...]): confirm, remove matching files, update metadata, summary & log.
- search_recycled(...): filter metadata by name and/or date-range, prints table, logs search.
- display_help(): CLI usage text including command descriptions, interactive mode, and --verbose option.
- show_statistics(): compute totals, quota percentage, type breakdown, oldest/newest, avg file size.
- auto_cleanup([--dry-run]): remove entries older than RETENTION_DAYS (from config), supports dry-run mode, logs actions.
- preview_file(<ID>): for text → head -n 10; binary → file(1) output + human-readable size.
- config_command(show|set): read or update MAX_SIZE_MB / RETENTION_DAYS in config, validate integers, confirm updates.
- version_command(): print version number and important paths (metadata, files, config).
- interactive_menu(): text-based interface for managing recycle bin (calls other functions interactively).
- debug(<message>): print yellow [DEBUG] messages to stderr when --verbose is active.
- main(...): entry point; parses arguments, handles command routing, manages verbose mode setup.


---

## 6. Design Decisions and Rationale
------------------------------

- Metadata as CSV-like plain text:
  - Pros: human-readable, easy to inspect or edit manually, no external DB dependency.
  - Cons: limited escaping; commas or newlines in filenames can break structure.
  - Rationale: chosen for simplicity and transparency in a shell-only environment.

- Storage separation (data vs. metadata):
  - Files stored in a "files/" subdirectory using generated unique IDs.
  - Metadata stored separately in "metadata.db".
  - Rationale: prevents filename collisions and allows safe handling of same-named files.

- Unique ID = epoch timestamp + random alphanumeric block:
  - Ensures uniqueness and natural chronological ordering.
  - Rationale: avoids collisions, allows time-based sorting, no need for external libraries.

- Configuration file as key=value text:
  - MAX_SIZE_MB and RETENTION_DAYS stored in a simple text file.
  - Rationale: easily editable by user or script; parsed using standard Unix tools (grep, cut, sed).

- Standard Unix tools (file, awk, sort, numfmt, date, grep):
  - Used instead of custom logic or dependencies.
  - Rationale: improves portability, maintainability, and efficiency across GNU/Linux systems.

- Auto-cleanup triggered asynchronously after each deletion:
  - Runs in background to avoid delaying user operations.
  - Rationale: maintains retention policy automatically while keeping the user experience responsive.

- Interactive mode for non-technical users:
  - Provides a numbered menu-based interface for all main operations.
  - Rationale: improves usability and accessibility without needing command-line flags.

- Verbose/debug mode (--verbose):
  - When enabled, prints internal [DEBUG] messages to stderr for tracing.
  - Rationale: facilitates troubleshooting without affecting normal program output.

- Color-coded terminal output:
  - Red for errors, green for success, yellow for warnings/debug.
  - Rationale: improves user feedback and readability in CLI.

- Retention and quota configuration stored persistently:
  - Config persists across sessions under ~/.recycle_bin/config.
  - Rationale: allows permanent customization without code changes.

- Defensive scripting and validation:
  - Validation for numeric inputs, y/n prompts, and command arguments.
  - Rationale: prevents invalid operations, reduces risk of data loss or corruption.


- Logging to recyclebin.log:
  - All destructive or major actions are recorded.
  - Rationale: ensures auditability and traceability of file operations.


## 7. Algorithm Explanations (Pseudocode / Summary)
---------------------------------------------

Initialize Recycle Bin:
1. Check if ~/.recycle_bin directory exists.
2. If not, create directory structure (files/, metadata.db, config, log).
3. Write metadata header and default config values.
4. Print confirmation message and exit.

Generate Unique ID:
1. Get current epoch timestamp.
2. Generate 10 random alphanumeric characters.
3. Concatenate timestamp + "_" + random string.
4. Return ID string (safe characters only).

Delete flow:
1. For each file argument:
   a. Validate existence and permissions.
   b. Skip if inside recycle bin itself.
   c. Collect metadata (path, owner, size, perms, etc.).
   d. Generate unique ID for storage.
   e. Move file to files/<ID>.
   f. Append metadata entry to metadata.db.
   g. Log deletion to recyclebin.log.
2. Run auto_cleanup asynchronously.

List flow:
1. Read metadata.db, skipping first two header lines.
2. Apply sorting options (--sort=name|date|size).
3. Reverse order if --reverse is set.
4. For each entry, format output (compact or detailed).
5. Compute total count and size, print summary.

Restore flow:
1. Validate ID given.
2. Find metadata entry matching ID (or name pattern).
3. Ensure $FILES_DIR/$id exists.
4. Ensure original path exists (mkdir -p if necessary).
5. If destination exists, choose overwrite / rename / cancel.
6. mv files/<ID> -> original_path/original_name.
7. chmod perms on destination.
8. Remove metadata entry and log restoration.

Empty flow:
1. Read metadata.db (skip headers).
2. If ID or --pattern given, filter matching entries.
3. Confirm with user (y/N).
4. For each matched entry:
   a. Delete files/<ID>.
   b. Remove metadata entry.
   c. Log deletion.
5. Display summary (count and total size deleted).

Search flow:
1. Read metadata.db (skip headers).
2. If name given, filter by substring (case-insensitive).
3. If --date-from or --date-to given, apply date filters.
4. Display formatted results (simple or detailed).

Show statistics flow:
1. Read all entries from metadata.db.
2. Compute total size, item count, and type counts.
3. Read quota and retention from config.
4. Calculate usage percentage and average file size.
5. Print summary including oldest and newest items.

Auto-cleanup flow:
1. Read RETENTION_DAYS from config.
2. Compute cutoff date (current_date - retention_days).
3. Load all metadata entries.
4. Identify entries older than cutoff date.
5. If --dry-run, list items that would be deleted.
6. Otherwise, delete files and remove entries from metadata.
7. Log cleanup actions and print summary.

Preview flow:
1. Read metadata.db and locate entry by ID.
2. If entry is a directory, print notice and exit.
3. If file:
   a. Detect MIME type using file(1).
   b. If text, show first 10 lines.
   c. If binary, show type description and file size.
4. Print end marker.

Config flow:
1. If "show" → read config values and print.
2. If "set quota" or "set retention":
   a. Validate numeric value > 0.
   b. Update config with sed (in-place edit).
   c. Print updated configuration.
3. Exit with confirmation.

Version flow:
1. Print version number and environment info.
2. Display paths: metadata file, files directory, config file.
3. Exit.

Interactive menu flow:
1. Display main menu and read user choice.
2. For each option, call the corresponding function:
   1) delete_file()
   2) list_recycled()
   3) restore_file()
   4) search_recycled()
   5) empty_recyclebin()
   6) show_statistics()
   7) auto_cleanup()
   8) preview_file()
   9) config_command show
   10) config_command set
   11) display_help()
   0) exit
3. Loop until user chooses Exit.

Debug flow:
1. Receive message string as input.
2. If VERBOSE=true, print message to stderr in yellow.
3. If VERBOSE=false, do nothing.

Main flow:
1. Parse CLI arguments.
2. Handle --verbose flag.
3. Auto-initialize recycle bin if missing.
4. Match first argument to command (case switch).
5. Execute corresponding function.
6. Handle invalid command with error message.

---

## 8. Flowcharts (ASCII) — complex ops

Complex Function Flowcharts
===========================

delete_file(...)
---------------
Start
 ↓
Check if user passed any files
 ├─ No → Print error, End
 └─ Yes
     ↓
     For each file:
       ↓
       Validate existence and permissions
       ├─ Invalid → Print error, log, skip
       └─ Valid
           ↓
           Check if file inside recycle bin
           ├─ Yes → Print error, skip
           └─ No
               ↓
               Collect metadata (name, path, date, size, perms, owner)
               ↓
               Generate unique ID
               ↓
               Move file → $FILES_DIR/<ID>
               ├─ Fail → Print error, log, skip
               └─ Success
                   ↓
                   Append row to metadata.db
                   ↓
                   Log deletion
                   ↓
                   Print confirmation
 ↓
Run auto_cleanup in background
 ↓
End


restore_file(<ID|pattern>)
--------------------------
Start
 ↓
Check if metadata file exists and not empty
 ├─ Empty → Print warning, End
 └─ Continue
     ↓
     Parse arguments (--id or pattern)
     ↓
     Locate matching entry in metadata
     ├─ None → Print error, End
     ├─ Multiple → Ask user to choose one
     └─ Single match
         ↓
         Check if file exists in $FILES_DIR/<ID>
         ├─ Missing → Print error, End
         └─ Exists
             ↓
             Ensure original directory exists (mkdir -p)
             ↓
             Move file back to original path
             ├─ Fail → Print error, End
             └─ Success
                 ↓
                 Restore original permissions
                 ↓
                 Remove entry from metadata
                 ↓
                 Log restoration
 ↓
Print success message
 ↓
End


empty_recyclebin([ID|--pattern])
--------------------------------
Start
 ↓
Load metadata entries (skip header)
 ↓
Check arguments:
   - ID → match exact ID
   - --pattern → match substring
   - None → select all
 ↓
If no matches → Print "Nothing deleted", End
 ↓
Ask user confirmation (y/n)
 ├─ n → Cancel, End
 └─ y
     ↓
     For each matched entry:
       - Delete file in files/<ID>
       - Remove metadata row
       - Log deletion
     ↓
     Summarize count + total size removed
 ↓
End


auto_cleanup([--dry-run])
-------------------------
Start
 ↓
Read retention days from config (default 30)
 ↓
Compute cutoff date (Now - RETENTION_DAYS)
 ↓
Read all metadata entries
 ↓
Find files older than cutoff
 ├─ None → Print "No old items", End
 └─ Found
     ↓
     If --dry-run:
         List items that would be deleted
     Else:
         For each old entry:
             - Delete files/<ID>
             - Remove metadata row
             - Log cleanup
 ↓
Print summary (# items, total size freed)
 ↓
End


interactive_menu()
------------------
Start
 ↓
Clear screen and show header
 ↓
Loop:
   Show numbered menu (1–10, 0 = Exit)
   ↓
   Read user choice
   ↓
   Match choice:
     1 → Ask for file paths → delete_file()
     2 → Ask "Detailed view?" → list_recycled()
     3 → Ask name/ID → restore_file()
     4 → Ask search pattern + optional dates → search_recycled()
     5 → Ask ID/pattern → empty_recyclebin()
     6 → show_statistics()
     7 → Ask "Dry-run?" → auto_cleanup()
     8 → Ask file ID → preview_file()
     9 → config_command show
    10 → Ask setting (quota/retention) → config_command set
    11 → display_help()
     0 → Exit loop
     * → Print "Invalid option"
   ↓
   Wait for Enter, clear screen, redisplay menu
 ↓
Print "Goodbye"
 ↓
End


## 9. Known limitations and future improvements
- Metadata CSV does not escape commas/newlines in filenames. Considering switching to JSON or proper CSV library.
- Concurrent operations can race when writing metadata file. Add file locking (flock) or atomic updates.
- No differential deduplication (identical content stored multiple times).
- No integrity checking (checksums) — consider storing SHA256 for verification.
- Better UX for interactive restore (non-interactive mode, flags).
- Add automated unit/integration tests (test_suite.sh placeholder is present).
- Password protection for sensitive operations and encryption of metadata.

---

## 10. Maintenance notes
- Config keys: MAX_SIZE_MB, RETENTION_DAYS
- Log file: $RECYCLE_BIN_DIR/recyclebin.log
- Metadata header lines must not be removed by hand; if repairing metadata, maintain header lines.
- To change retention or quota: edit $RECYCLE_BIN_DIR/config or run ./recycle_bin.sh config set retention (DAYS) and ./recycle_bin.sh config set quota (MB)

---

## 11. References

GNU Awk User’s Guide - https://www.gnu.org/software/gawk/manual/ (Last consulted at 31-10-2025);
GNU Bash Manual - https://www.gnu.org/software/bash/manual/ (Last consulted at 31-10-2025);
Stack Overflow; 
Reddit Linux and bash programming subs;
Linux Man Pages;


<!-- End of Technical Documentation -->
