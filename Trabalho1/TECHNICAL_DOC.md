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
User -> recycle_bin.sh (delete) -> validate -> mv file -> write metadata row -> log -> optional auto_cleanup

Restore operation:
User -> recycle_bin.sh (restore <ID>) -> lookup metadata -> mv file back -> restore perms -> remove metadata row -> log

Search/list/statistics:
User -> script -> read metadata.db -> filter/aggregate -> stdout -> log (search)

Auto-cleanup:
script -> read config (RETENTION_DAYS) -> compute cutoff_date -> scan metadata -> delete matched files -> remove metadata rows -> log & summary

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

## 5. Function descriptions (short)
- initialize_recyclebin(): create directories, default config, and metadata header.
- generate_unique_id(): returns epoch_random string used as stored filename.
- delete_file(...): validate, collect stat metadata, move item to files/<ID>, append metadata, log.
- list_recycled(...): read metadata, optional --detailed and --sort modes, pretty-print, compute totals.
- restore_file(<ID>): find entry, move files/<ID> back to original path, restore perms, remove metadata, log.
- empty_recyclebin([ID|--pattern=...]): confirm, remove matching files, update metadata, summary & log.
- search_recycled(...): filter metadata by name and/or date-range, prints table, logs search.
- display_help(): CLI usage text.
- show_statistics(): compute totals, quota percentage, type breakdown, oldest/newest, avg file size.
- auto_cleanup([--dry-run]): remove entries older than RETENTION_DAYS (from config), supports dry-run.
- preview_file(<ID>): for text -> head -n 10; binary -> file(1) output + human size.

---

## 6. Design decisions and rationale
- Metadata as CSV-like plain text:
  - Pros: human-readable, easy to edit, no DB dependency.
  - Cons: concurrency and escaping special characters need care. Current CSV usage presumes filenames are not containing newlines; commas inside names would disrupt columns. Simplicity chosen due to shell environment.
- Storage separation:
  - Files stored by unique ID, preventing name collisions.
- Unique ID = epoch + random:
  - Low collision risk, sortable by time.
- Config in plain text key=value:
  - Easy to parse with grep/cut, edit by user.
- Use standard Unix tools (file, numfmt, awk, sort):
  - Maximizes portability and reduces dependencies.
- Auto-cleanup runs in background after delete:
  - Keeps delete fast; avoids blocking user commands.

---

## 7. Algorithm explanations (pseudocode / summary)

Generate ID:
- timestamp = date +%s
- random = head of /dev/urandom filtered to alphanum (6 chars)
- id = "${timestamp}_${random}"

Delete flow:
1. For each path argument:
   - refuse paths under RECYCLE_BIN_DIR
   - check exists, permissions
   - collect metadata via stat
   - id = generate_unique_id()
   - mv path -> "$FILES_DIR/$id"
   - append CSV line to metadata.db
   - log to recyclebin.log
2. After loop, optionally spawn auto_cleanup in background.

Restore flow:
1. Validate ID given
2. Find metadata entry matching ID
3. Ensure $FILES_DIR/$id exists
4. Ensure original path exists (mkdir -p if necessary)
5. If destination exists, choose overwrite / rename / cancel
6. mv files/id -> destination
7. chmod perms on destination
8. Remove metadata entry and log

Search operation:
- Read metadata rows (skip header)
- If name_pattern present: case-insensitive substring match on ORIGINAL_NAME
- If date_from/date_to present: awk filters on DELETION_DATE
- Output table; log count

Statistics:
- total_items = number of metadata rows
- total_size = sum(FILE_SIZE)
- quota from config MAX_SIZE_MB -> usage percent = total_size / (MAX_SIZE_MB*1024*1024)
- file vs directory counts via grep on FILE_TYPE
- newest/oldest via sorting on DELETION_DATE
- average file size computed from file rows only

Auto-cleanup:
- retention_days read from config (default 30)
- cutoff_date = date -retention_days
- find rows with DELETION_DATE <= cutoff_date
- if dry-run: list would-be deletes
- else: rm -rf files/<ID> and remove rows from metadata
- log and print summary

---

## 8. Flowcharts (ASCII) — complex ops

Delete (high-level):
  Start
    |
    v
  For each argument
    |
    +--> Is path inside recycle bin? -- Yes --> Log & skip --> (next)
    |
    +--> Exists? -- No --> Log error & skip --> (next)
    |
    +--> Permission OK? -- No --> Log error & skip --> (next)
    |
    v
  Gather metadata -> generate ID -> move item to files/<ID> -> append metadata -> log -> (next)
    |
    v
  End

Auto-cleanup:
  Start
    |
    v
  Read RETENTION_DAYS from config
    |
    v
  Compute cutoff date/time
    |
    v
  Read metadata rows (skip headers)
    |
    v
  Filter rows with DELETION_DATE <= cutoff
    |
    +--> No matches -> Print "nothing to do" -> End
    |
    +--> Matches found
           |
           +--> Dry-run? -- Yes --> List matches -> Show summary -> End
           |
           v
         Remove files/<ID> for each match -> Remove metadata rows -> Log actions -> Show summary -> End

Restore (conflict handling):
  Start
    |
    v
  Lookup ID in metadata
    |
    +--> Not found -> Error -> End
    |
    v
  Ensure files/<ID> exists
    |
    v
  Prepare destination path (mkdir -p if needed)
    |
    +--> Destination exists? -- Yes --> Prompt: overwrite / rename / cancel
    |                                 |
    |                                 +--> Cancel -> Exit
    |                                 +--> Overwrite/rename -> continue
    |
    v
  Move files/<ID> -> destination -> restore permissions -> remove metadata entry -> Log -> Success -> End


---

## 9. Known limitations and future improvements
- Metadata CSV does not escape commas/newlines in filenames. Consider switching to JSON or proper CSV library.
- Concurrent operations can race when writing metadata file. Add file locking (flock) or atomic updates.
- No differential deduplication (identical content stored multiple times).
- No integrity checking (checksums) — consider storing SHA256 for verification.
- Better UX for interactive restore (non-interactive mode, flags).
- Add automated unit/integration tests (test_suite.sh placeholder is present).

---

## 10. Maintenance notes
- Config keys: MAX_SIZE_MB, RETENTION_DAYS
- Log file: $RECYCLE_BIN_DIR/recyclebin.log
- Metadata header lines must not be removed by hand; if repairing metadata, maintain header lines.
- To change retention or quota: edit $RECYCLE_BIN_DIR/config

---

## 11. References
- Unix utilities used: awk, sed, sort, head, file, numfmt, stat, mv, rm

<!-- End of Technical Documentation -->
