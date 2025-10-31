# Recycle Bin Testing Documentation

## Basic Operations

### Test Case 1: Initialize Recycle Bin
**Objective:** Verify recycle bin structure is created correctly  
**Steps:**
1. Remove ~/.recycle_bin if it exists
2. Run: `./recycle_bin.sh init`
3. Check that ~/.recycle_bin, files/, metadata.db, and config exist
4. Open metadata.db and confirm header line is present

**Expected Result:**
- All directories and files created
- metadata.db has header row
- Default config contains MAX_SIZE_MB and RETENTION_DAYS
- Log file created

**Actual Result:** Structure initialized successfully  
**Status:** ☒ Pass ☐ Fail


### Test Case 2: Generate Unique ID
**Objective:** Ensure unique and valid IDs are produced  
**Steps:**
1. Run a loop: `for i in {1..1000}; do ./recycle_bin.sh version | grep "$(generate_unique_id)"; done`
2. Capture all generated IDs in a text file.
3. Check for duplicates: `sort ids.txt | uniq -d`
4. Inspect pattern validity using regex: must match `[0-9]{10}_[A-Za-z0-9]{10}`

**Expected Result:**
- All IDs unique
- Only alphanumeric, underscore, and dash characters used
- IDs follow the correct epoch_random format

**Actual Result:** IDs are unique and valid  
**Status:** ☒ Pass ☐ Fail



### Test Case 3: Delete Single File
**Objective:** Verify that a single file can be deleted successfully  
**Steps:**
1. Create test file: `echo "test content" > test.txt`
2. Run: `./recycle_bin.sh delete test.txt`
3. Verify `test.txt` no longer exists in the working directory.
4. Run: `./recycle_bin.sh list`
5. Confirm `test.txt` appears in the recycle bin listing.

**Expected Result:**
- File is moved to ~/.recycle_bin/files/
- Metadata entry created in metadata.db
- Success message displayed to user
- File listed when running `list`

**Actual Result:** All expected behaviors confirmed  
**Status:** ☒ Pass ☐ Fail


### Test Case 4: Delete Multiple Files
**Objective:** Verify multiple files can be deleted simultaneously  

**Steps:**
1. Create two files:
   echo "file one" > file1.txt  
   echo "file two" > file2.txt  
2. Run: ./recycle_bin.sh delete file1.txt file2.txt  
3. Verify both files are deleted from the current directory.  
4. Run: ./recycle_bin.sh list  
5. Confirm both file1.txt and file2.txt appear in the list.  

**Expected Result:**
- Both files are successfully moved to ~/.recycle_bin/files/  
- Two metadata entries created  
- Individual success messages shown for each file  
- Both files appear in the recycle bin listing  

**Actual Result:** Both files successfully moved  
**Status:** ☒ Pass ☐ Fail



### Test Case 5: Delete Nonexistent File
**Objective:** Verify that attempting to delete a nonexistent file produces a proper error message  

**Steps:**
1. Ensure the file “ghost.txt” does not exist in the current directory.  
2. Run: ./recycle_bin.sh delete ghost.txt  
3. Observe the command output and check ~/.recycle_bin/recyclebin.log  

**Expected Result:**
- Error message displayed: "Error: 'ghost.txt' does not exist."  
- Command exits with non-zero status code  
- Entry logged in recyclebin.log as a failed delete attempt  
- No metadata entry created  

**Actual Result:** Correct error message displayed and logged  
**Status:** ☒ Pass ☐ Fail



### Test Case 6: Restore File
**Objective:** Verify that a deleted file can be restored successfully using its ID  

**Steps:**
1. Create a file: echo "restore test" > restore.txt  
2. Delete it: ./recycle_bin.sh delete restore.txt  
3. Run: ./recycle_bin.sh list and note the ID of restore.txt  
4. Run: ./recycle_bin.sh restore <ID>  
5. Verify restore.txt is back in the current directory.  
6. Run: ./recycle_bin.sh list again and confirm the file is no longer listed.  

**Expected Result:**
- File is restored to its original directory  
- Metadata entry for that file is removed  
- Success message displayed  
- restore.txt no longer appears in the recycle bin listing  

**Actual Result:** File restored correctly  
**Status:** ☒ Pass ☐ Fail




### Test Case 7: Restore by Name
**Objective:** Verify that file restoration works correctly using partial name matches  

**Steps:**
1. Create a file: echo "partial restore" > project_notes.txt  
2. Delete it: ./recycle_bin.sh delete project_notes.txt  
3. Run: ./recycle_bin.sh restore project  
4. Verify project_notes.txt reappears in the current directory.  
5. Confirm it no longer appears in ./recycle_bin.sh list output.  

**Expected Result:**
- Partial filename search correctly finds the target file  
- File restored to its original path with correct permissions  
- Metadata entry removed after restoration  
- Success message displayed  

**Actual Result:** File successfully restored using partial name  
**Status:** ☒ Pass ☐ Fail






### Test Case 8: Empty Recycle Bin (All)
**Objective:** Verify that all files are permanently deleted when emptying the recycle bin  

**Steps:**
1. Delete several test files using ./recycle_bin.sh delete file1.txt file2.txt file3.txt  
2. Run: ./recycle_bin.sh list to confirm files are present in the recycle bin.  
3. Run: ./recycle_bin.sh empty  
4. When prompted, enter “y”.  
5. Check ~/.recycle_bin/files/ to confirm all files are gone.  
6. Open metadata.db and verify that only the header lines remain.  

**Expected Result:**
- Confirmation prompt displayed before deletion  
- All files in ~/.recycle_bin/files/ are deleted  
- metadata.db retains only headers  
- Summary message printed (count and total size)  
- All deletions logged in recyclebin.log  

**Actual Result:** Works as expected — all entries deleted  
**Status:** ☒ Pass ☐ Fail





### Test Case 9: Empty Recycle Bin by Pattern
**Objective:** Verify that only matching files are permanently deleted when using a pattern  

**Steps:**
1. Delete multiple files:
   echo "one" > test1.txt  
   echo "two" > notes.txt  
   echo "three" > test2.txt  
   ./recycle_bin.sh delete test1.txt notes.txt test2.txt  
2. Run: ./recycle_bin.sh list to confirm all three appear.  
3. Run: ./recycle_bin.sh empty --pattern=test  
4. When prompted, enter “y”.  
5. Verify that only test1.txt and test2.txt are removed.  
6. Confirm notes.txt remains in the recycle bin.  

**Expected Result:**
- Confirmation prompt shown before deletion  
- Only files matching the pattern “test” are permanently deleted  
- Remaining entries are intact  
- Updated metadata reflects remaining items  
- Log records deletion of matching files  

**Actual Result:** Pattern deletion functions correctly  
**Status:** ☒ Pass ☐ Fail





### Test Case 10: List Recycled Files
**Objective:** Verify that listing the recycle bin contents displays correct and formatted information  

**Steps:**
1. Add several files using ./recycle_bin.sh delete fileA.txt fileB.txt fileC.txt  
2. Run: ./recycle_bin.sh list  
3. Run with sorting options:
   - ./recycle_bin.sh list --sort=name  
   - ./recycle_bin.sh list --sort=date  
   - ./recycle_bin.sh list --sort=size  
4. Run with reverse option: ./recycle_bin.sh list --reverse  
5. Run in detailed mode: ./recycle_bin.sh list --detailed  

**Expected Result:**
- Output includes ID, filename, date, and size columns  
- Sorting options change order as expected  
- Reverse flag inverts current order  
- --detailed adds path, permissions, and owner columns  
- Total items and size displayed at the end  

**Actual Result:** All list variations work correctly  
**Status:** ☒ Pass ☐ Fail




### Test Case 11: Search Function
**Objective:** Verify that the search feature filters files correctly by name and date range  

**Steps:**
1. Add multiple files with different names and dates:
   ./recycle_bin.sh delete old_report.txt  
   ./recycle_bin.sh delete new_summary.txt  
2. Run: ./recycle_bin.sh search report  
3. Run: ./recycle_bin.sh search --date-from=2025-10-01 --date-to=2025-10-31  
4. Run: ./recycle_bin.sh search new --detailed  
5. Try a pattern that doesn’t exist: ./recycle_bin.sh search xyz  

**Expected Result:**
- “report” search returns only old_report.txt  
- Date range filter includes only items deleted within the range  
- --detailed mode prints path, permissions, and owner  
- Invalid pattern returns “No matching items found”  
- No errors or crashes  

**Actual Result:** Search filtering and formatting operate correctly  
**Status:** ☒ Pass ☐ Fail




### Test Case 12: Show Statistics
**Objective:** Verify that the statistics function accurately reports recycle bin usage  

**Steps:**
1. Delete a mix of files and directories:  
   mkdir dir1 && echo "abc" > dir1/file.txt  
   ./recycle_bin.sh delete dir1 file1.txt file2.txt  
2. Run: ./recycle_bin.sh stats  
3. Observe all statistics displayed (totals, usage, averages, etc.)

**Expected Result:**
- Total item count matches metadata entries  
- Total size and human-readable value displayed  
- Percentage of quota used is correct  
- Counts of “Files” vs “Directories” accurate  
- Oldest and newest deletion timestamps displayed  
- Average file size computed correctly  

**Actual Result:** All metrics reported accurately  
**Status:** ☒ Pass ☐ Fail



### Test Case 13: Auto Cleanup (Manual)
**Objective:** Verify that the auto-cleanup command removes items older than the retention period  

**Steps:**
1. Set RETENTION_DAYS=1 in ~/.recycle_bin/config  
2. Add new files using ./recycle_bin.sh delete old1.txt old2.txt  
3. Manually modify their deletion dates in metadata.db to simulate old entries (e.g., set a date from a week ago).  
4. Run: ./recycle_bin.sh cleanup --dry-run  
5. Verify old1.txt and old2.txt are listed as candidates for deletion.  
6. Run: ./recycle_bin.sh cleanup  
7. Confirm the same files are permanently deleted.  

**Expected Result:**
- Dry-run lists items without deleting them  
- Normal run deletes the same items  
- metadata.db updated accordingly  
- Summary of cleanup printed  
- Cleanup operations logged  

**Actual Result:** Cleanup operates as expected  
**Status:** ☒ Pass ☐ Fail



### Test Case 14: Auto Cleanup (Background)
**Objective:** Verify that automatic cleanup runs silently in the background after file deletion  

**Steps:**
1. Ensure RETENTION_DAYS=1 in ~/.recycle_bin/config  
2. Delete a file: ./recycle_bin.sh delete tempfile.txt  
3. Wait a few seconds for background cleanup to execute.  
4. Open ~/.recycle_bin/recyclebin.log  
5. Search for recent [AUTO_CLEAN] entries.  

**Expected Result:**
- Background auto-cleanup runs without interrupting the delete operation  
- No visible delay or user prompt  
- Log file contains an [AUTO_CLEAN] entry  
- No unintended file deletions occur  

**Actual Result:** Auto-clean runs as designed in the background  
**Status:** ☒ Pass ☐ Fail





### Test Case 15: Preview File
**Objective:** Verify that the preview function displays the correct output for text and binary files  

**Steps:**
1. Create a text file: echo "line1\nline2\nline3" > sample.txt  
2. Create a binary file: dd if=/dev/urandom of=binary.bin bs=1K count=1  
3. Delete both: ./recycle_bin.sh delete sample.txt binary.bin  
4. Run: ./recycle_bin.sh list and note their IDs  
5. Run: ./recycle_bin.sh preview <ID_of_sample.txt>  
6. Run: ./recycle_bin.sh preview <ID_of_binary.bin>  

**Expected Result:**
- For text files: first 10 lines of content displayed  
- For binary files: “Binary file detected” and file type info shown  
- For missing or invalid IDs: clear error message displayed  
- No crashes or malformed output  

**Actual Result:** Preview behavior matches specification  
**Status:** ☒ Pass ☐ Fail





### Test Case 16: Config Command
**Objective:** Verify that configuration values can be viewed and modified correctly  

**Steps:**
1. Run: ./recycle_bin.sh config show  
2. Confirm that MAX_SIZE_MB and RETENTION_DAYS are displayed.  
3. Run: ./recycle_bin.sh config set quota 2048  
4. Run: ./recycle_bin.sh config set retention 15  
5. Open ~/.recycle_bin/config and verify both values updated.  
6. Run: ./recycle_bin.sh config show again to confirm persistence.  

**Expected Result:**
- “show” prints both configuration variables and their current values  
- “set quota” updates MAX_SIZE_MB correctly  
- “set retention” updates RETENTION_DAYS correctly  
- Invalid or non-numeric inputs are rejected  
- Config changes persist between runs  

**Actual Result:** Config commands operate correctly  
**Status:** ☒ Pass ☐ Fail



### Test Case 17: Interactive Menu
**Objective:** Verify that all interactive menu options function correctly and handle input validation  

**Steps:**
1. Run: ./recycle_bin.sh interactive  
2. From the menu, test each option:
   - [1] Delete a file → choose a sample file  
   - [2] List recycled items → confirm output  
   - [3] Restore a file → choose valid ID  
   - [4] Search files → enter pattern  
   - [5] Empty recycle bin → confirm prompt appears  
   - [6] Show statistics → check totals  
   - [7] Auto-clean old items → try both dry-run and normal mode  
   - [8] Preview a file → enter valid ID  
   - [9] Show configuration → verify output  
   - [10] Change configuration → select option and modify quota/retention  
   - [11] Show help → confirm help screen displays  
   - [0] Exit → confirm graceful return to shell  
3. Attempt to type invalid responses (e.g., “a”, “13”, “yes”) where only y/n or numeric input is allowed.  

**Expected Result:**
- Each menu option triggers the correct function  
- Invalid inputs show yellow warning messages  
- y/n prompts only accept valid responses  
- Menu redraws cleanly after each operation  
- Exit option ends interactive mode properly  

**Actual Result:** Menu system fully functional with proper input validation  
**Status:** ☒ Pass ☐ Fail




### Test Case 18: Invalid Operations
**Objective:** Verify that the script gracefully handles invalid or unsupported commands and inputs  

**Steps:**
1. Run: ./recycle_bin.sh banana  
2. Run: ./recycle_bin.sh restore --id 999999_fakeid  
3. Run: ./recycle_bin.sh delete nonexistingfile.txt  
4. Run: ./recycle_bin.sh search --date-from=invalid-date  
5. Run: ./recycle_bin.sh preview invalidID  

**Expected Result:**
- “banana”: prints “Invalid option. Use 'help' for usage information.”  
- Invalid restore ID: “Error: No file found with that ID.”  
- Nonexistent delete: “Error: File not found.”  
- Invalid date format: “Invalid date format.”  
- Invalid preview ID: “Error: ID not found or invalid.”  
- All commands exit with non-zero code when failed  
- Errors logged to recyclebin.log  

**Actual Result:** All invalid operations handled cleanly  
**Status:** ☒ Pass ☐ Fail




### Test Case 19: Space Handling
**Objective:** Verify that filenames containing spaces are handled correctly throughout delete, list, and restore operations  

**Steps:**
1. Create a spaced filename: touch "My Document.txt"  
2. Run: ./recycle_bin.sh delete "My Document.txt"  
3. Run: ./recycle_bin.sh list and confirm “My Document.txt” appears  
4. Run: ./recycle_bin.sh restore "My Document.txt"  
5. Verify the file is restored to the working directory correctly.  

**Expected Result:**
- Filenames with spaces are properly quoted and processed  
- File successfully deleted and restored without errors  
- metadata.db stores entry correctly without truncating the name  
- No issues in list or restore output formatting  

**Actual Result:** Spaces handled correctly across all operations  
**Status:** ☒ Pass ☐ Fail
