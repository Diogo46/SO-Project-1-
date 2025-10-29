# Recycle Bin Testing Documentation

## Basic Operations

### Test Case 1: Delete Single File
**Objective:** Verify that a single file can be deleted successfully
**Steps:**
1. Create test file: `echo "test" > test.txt`
2. Run: `./recycle_bin.sh delete test.txt`
3. Verify file is removed from current directory
4. Run: `./recycle_bin.sh list`
5. Verify file appears in recycle bin

**Expected Result:**
- File is moved to ~/.recycle_bin/files/
- Metadata entry is created
- Success message is displayed
- File appears in list output

**Actual Result:** All expected behaviors confirmed
**Status:** ☒ Pass ☐ Fail

### Test Case 2: Delete Multiple Files
**Objective:** Verify multiple files can be deleted in one command
**Steps:**
1. Create test files: 
```bash
echo "test1" > file1.txt
echo "test2" > file2.txt
```
2. Run: `./recycle_bin.sh delete file1.txt file2.txt`
3. Verify both files are removed
4. Check recycle bin contents

**Expected Result:**
- Both files moved to recycle bin
- Two metadata entries created
- Success message for each file
- Both files in list output

**Actual Result:** All files successfully moved
**Status:** ☒ Pass ☐ Fail

### Test Case 3: Restore File
**Objective:** Verify file restoration works correctly
**Steps:**
1. Delete a file: `./recycle_bin.sh delete document.txt`
2. Note the file ID from list output
3. Run: `./recycle_bin.sh restore <ID>`
4. Verify file returns to original location

**Expected Result:**
- File restored to original path
- Metadata entry removed
- Success message shown
- File no longer in recycle bin list

**Actual Result:** File restored successfully
**Status:** ☒ Pass ☐ Fail

### Test Case 4: Search Function
**Objective:** Test search functionality with various criteria
**Steps:**
1. Add multiple files to recycle bin
2. Search by name: `./recycle_bin.sh search test`
3. Search by date: `./recycle_bin.sh search --date-from=2025-10-01`
4. Test detailed output: `./recycle_bin.sh search test --detailed`

**Expected Result:**
- Matching files displayed
- Date filtering works
- Detailed mode shows all metadata
- No errors for invalid searches

**Actual Result:** Search working as expected
**Status:** ☒ Pass ☐ Fail

### Test Case 5: Statistics Display
**Objective:** Verify statistics reporting
**Steps:**
1. Add various files to recycle bin
2. Run: `./recycle_bin.sh stats`

**Expected Result:**
- Shows total items count
- Displays storage usage
- Shows quota percentage
- Lists newest/oldest items
- Shows file type breakdown

**Actual Result:** All statistics displayed correctly
**Status:** ☒ Pass ☐ Fail

### Test Case 6: Auto-Cleanup
**Objective:** Test automatic cleanup of old files
**Steps:**
1. Set RETENTION_DAYS=1 in config
2. Add test files
3. Wait 24+ hours
4. Run: `./recycle_bin.sh cleanup`

**Expected Result:**
- Old files removed
- Metadata updated
- Summary displayed
- Newer files retained

**Actual Result:** Cleanup executed properly
**Status:** ☒ Pass ☐ Fail

### Test Case 7: File Preview
**Objective:** Test file preview functionality
**Steps:**
1. Add text and binary files
2. Get file IDs from list
3. Run: `./recycle_bin.sh preview <ID>` for each

**Expected Result:**
- Text files: shows first 10 lines
- Binary files: shows type info
- Proper error for missing files
- Directory preview handled

**Actual Result:** Preview works as designed
**Status:** ☒ Pass ☐ Fail

## Error Handling

### Test Case 8: Invalid Operations
**Objective:** Verify proper error handling
**Steps:**
1. Try to restore non-existent ID
2. Delete non-existent file
3. Search with invalid date format
4. Preview invalid ID

**Expected Result:**
- Clear error messages
- Non-zero exit codes
- No system crashes
- Proper logging

**Actual Result:** All errors handled gracefully
**Status:** ☒ Pass ☐ Fail

### Test Case 9: Space Handling
**Objective:** Test handling of filenames with spaces
**Steps:**
1. Create file: `touch "My Document.txt"`
2. Delete: `./recycle_bin.sh delete "My Document.txt"`
3. List and verify
4. Restore file

**Expected Result:**
- Spaces handled correctly
- No parsing errors
- Proper restoration path

**Actual Result:** Spaces handled properly
**Status:** ☒ Pass ☐ Fail
