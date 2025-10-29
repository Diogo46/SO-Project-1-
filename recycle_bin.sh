#!/bin/bash


#########################################################################################
# Linux Recycle Bin Simulation
# Authors: Diogo Ferreira Martins, Hélio Filho
# Date: 2025-10-10
# Description: Shell-based recycle bin system
#########################################################################################


# Global Configuration
RECYCLE_BIN_DIR="$HOME/.recycle_bin"
FILES_DIR="$RECYCLE_BIN_DIR/files"
METADATA_FILE="$RECYCLE_BIN_DIR/metadata.db"
CONFIG_FILE="$RECYCLE_BIN_DIR/config"

# Color Codes 
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


#################################################
# Function: initialize_recyclebin
# Description: Creates recycle bin directory structure
# Parameters: None
# Returns: 0 on success, 1 on failure
#################################################
initialize_recyclebin() {
    if [ ! -d "$RECYCLE_BIN_DIR" ]; then
        mkdir -p "$FILES_DIR"
        touch "$METADATA_FILE"
        echo "# Recycle Bin Metadata" > "$METADATA_FILE"
        echo "ID,ORIGINAL_NAME,ORIGINAL_PATH,DELETION_DATE,FILE_SIZE,FILE_TYPE,PERMISSIONS,OWNER" >> "$METADATA_FILE"

        touch "$CONFIG_FILE"
        echo "MAX_SIZE_MB=1024" > "$CONFIG_FILE"  #  1024 MBmax size
        echo "RETENTION_DAYS=30" >> "$CONFIG_FILE"  # days to keep files

        touch "$RECYCLE_BIN_DIR/recyclebin.log"
        echo "Recycle bin initialized at $RECYCLE_BIN_DIR"
        return 0
    fi
    return 0


}


#################################################
# Function: generate_unique_id
# Description: Generates unique ID for deleted files
# Parameters: None
# Returns: Prints unique ID to stdout
#################################################
generate_unique_id() {
    local timestamp=$(date +%s)
    local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
    echo "${timestamp}_${random}"
}


#################################################
# Function: delete_file
# Description: Moves file/directory to recycle bin
# Parameters: $1 - path to file/directory
# Returns: 0 on success, 1 on failure
#################################################
delete_file() {
    # TODO: Implement this function

    if [ "$#" -eq 0 ]; then
        echo -e "${RED}Error: No file specified${NC}"
        return 1
    fi

    for file_path in "$@"; do
        # Prevent deleting the recycle bin itself 
        if [[ "$file_path" == "$RECYCLE_BIN_DIR"* ]]; then
            echo -e "${RED}Error: Cannot delete the recycle bin itself!${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Attempted to delete recycle bin: $file_path" >> "$RECYCLE_BIN_DIR/recyclebin.log"
            continue
        fi

        # Check if file exists
        if [ ! -e "$file_path" ]; then
            echo -e "${RED}Error: '$file_path' does not exist.${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to delete '$file_path' (not found)" >> "$RECYCLE_BIN_DIR/recyclebin.log"
            continue
        fi

        # Check permissions (read/write)
        if [ ! -r "$file_path" ] || [ ! -w "$(dirname "$file_path")" ]; then
            echo -e "${RED}Error: No permission to delete '$file_path'${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Permission denied for '$file_path'" >> "$RECYCLE_BIN_DIR/recyclebin.log"
            continue
        fi
   


        # Your code here
        # Hint: Get file metadata using stat command
        local original_name=$(basename "$file_path")
        local original_path=$(dirname "$file_path")
        local deletion_date=$(date '+%Y-%m-%d %H:%M:%S')
        local file_size=$(stat -c %s "$file_path")
        local file_type=$( [ -d "$file_path" ] && echo "directory" || echo "file" )
        local original_permissions=$(stat -c %a "$file_path")
        local original_owner=$(stat -c %U:%G "$file_path")


        # Hint: Generate unique ID
        local file_id=$(generate_unique_id)


        # Hint: Move file to FILES_DIR with unique ID
        # Preserve directories recursively
        if [ -d "$file_path" ]; then
            mv "$file_path" "$FILES_DIR/$file_id"
        else
            mv "$file_path" "$FILES_DIR/$file_id"
        fi

        # Hint: Add entry to metadata file
        echo "$file_id,$original_name,$original_path,$deletion_date,$file_size,$file_type,$original_permissions,$original_owner" >> "$METADATA_FILE"

        # Log the deletion
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Deleted '$file_path' as ID '$file_id'" >> "$RECYCLE_BIN_DIR/recyclebin.log"

        # User feedback
        echo -e "${GREEN}'$original_name' moved to Recycle Bin (ID: $file_id)${NC}"


    done
    echo "Delete function called with: $file_path"
    return 0
}


#################################################
# Function: list_recycled
# Description: Lists all items in recycle bin
# Parameters: None
# Returns: 0 on success
#################################################

list_recycled() {
    local detailed_mode=false
    local sort_option="none"

    # Parse flags like --detailed and --sort
    for arg in "$@"; do
        case "$arg" in
            --detailed)
                detailed_mode=true #shows full metadata
                ;;
            --sort=*)
                sort_option="${arg#--sort=}" #extracts value after '=', (name, date, size)
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$arg'${NC}" #flag validation (if it's not name date or size -> error)
                echo "Valid options: --detailed, --sort=name|date|size"
                return 1
                ;;
        esac
    done

    # make sure the sort option is valid 
    case "$sort_option" in
        none|name|date|size) ;; #valid options
        *)
            echo -e "${RED}Error: Invalid sort option '$sort_option'${NC}"
            echo "Valid sort options: name, date, size"
            return 1
            ;;
    esac

    #if the file doesnt exist OR only has header rows -> nothing to show
    if [ ! -s "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 2 ]; then
        echo "Recycle bin is empty."
        return 0
    fi

    echo "=== Recycle Bin Contents ==="
    echo

    # grab metadata entries (skips the 2 header lines)
    local data
    data=$(tail -n +3 "$METADATA_FILE")

    # Apply sorting based on selected option
    case "$sort_option" in
        name)  data=$(echo "$data" | sort -t ',' -f -k2,2) ;;    # A to Z, case insensitive 
        date)  data=$(echo "$data" | sort -t ',' -k4,4r) ;;      # newest first (desc)
        size)  data=$(echo "$data" | sort -t ',' -k5,5nr) ;;     # biggest first (desc)
    esac

    local total_size=0
    local count=0

    if ! $detailed_mode; then
        # basic table 
        printf "%-18s | %-20s | %-19s | %-10s\n" "ID" "Name" "Deleted At" "Size"
        printf "%s\n" "--------------------------------------------------------------------------------"
        
        # loops through each CSV row and prints what the info we need
        while IFS=',' read -r id name path date size type perms owner; do
            [[ -z "$id" ]] && continue
            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
            printf "%-18s | %-20s | %-19s | %-10s\n" "${id:0:18}" "$name" "$date" "$human_size"

            total_size=$(( total_size + size ))
            count=$(( count + 1 ))
        done <<< "$data"
    else
        # table for detailed mode
        printf "%-18s | %-20s | %-40s | %-19s | %-10s | %-8s | %-10s | %-12s\n" \
               "ID" "Name" "Path" "Deleted At" "Size" "Type" "Perms" "Owner"
        printf "%s\n" "-----------------------------------------------------------------------------------------------------------------------------------------------------"
        
        while IFS=',' read -r id name path date size type perms owner; do
            [[ -z "$id" ]] && continue
            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
            local short_path=$(printf "%.40s" "$path") #truncates long paths so table doesnt break
            printf "%-18s | %-20s | %-40s | %-19s | %-10s | %-8s | %-10s | %-12s\n" \
                   "$id" "$name" "$short_path" "$date" "$human_size" "$type" "$perms" "$owner"

            total_size=$(( total_size + size ))
            count=$(( count + 1 ))
        done <<< "$data"
    fi

    echo
    echo "Total items: $count"
    echo "Total size:  $(numfmt --to=iec --suffix=B "$total_size" 2>/dev/null)"
    return 0
}

#################################################
# Function: restore_file
# Description: Restores file from recycle bin
# Parameters: $1 - unique ID of file to restore
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
    # TODO: Implement this function
    local file_id="$1"
    if [ -z "$file_id" ]; then
        echo -e "${RED}Error: No file ID specified${NC}"
        return 1
    fi
    # Your code here

    # Hint: Search metadata for matching ID
    if [ ! -f "$METADATA_FILE" ] || [ $(wc -l < "$METADATA_FILE") -le 2 ]; then
        echo -e "${YELLOW}Recycle bin is empty or metadata file missing.${NC}"
        return 1
    fi

    local entry=$(tail -n +3 "$METADATA_FILE" | grep -m 1 "$file_id")

    if [ -z "$entry" ]; then
        echo -e "${RED}Error: No matching entry found for '$file_id'${NC}"
        return 1
    fi
    # Hint: Get original path from metadata
    IFS=',' read -r file_id original_name original_path deletion_date file_size file_type perms owner <<< "$entry"

    local source_path="$FILES_DIR/$file_id"
    local destination_path="$original_path/$original_name"

    # Hint: Check if original path exists
    if [ ! -e "$source_path" ]; then
        echo -e "${RED}Error: File not found in recycle bin storage (${source_path})${NC}"
        return 1
    fi

    # Check if original directory still exists; if not, create it
    if [ ! -d "$original_path" ]; then
        echo -e "${YELLOW}Original directory missing. Creating: $original_path${NC}"
        mkdir -p "$original_path" || {
            echo -e "${RED}Error: Failed to create destination directory${NC}"
            return 1
        }
    fi

    # Handle conflicts (file already exists at destination)
    if [ -e "$destination_path" ]; then
        echo -e "${YELLOW}Conflict: File already exists at destination.${NC}"
        echo "Choose an option:"
        echo "1) Overwrite existing file"
        echo "2) Restore with modified name (append timestamp)"
        echo "3) Cancel restoration"
        read -p "Enter choice [1-3]: " choice

        case $choice in
            1)
                echo "Overwriting existing file..."
                ;;
            2)
                local timestamp=$(date +%Y%m%d_%H%M%S)
                destination_path="${original_path}/${original_name%.*}_${timestamp}.${original_name##*.}"
                echo "Restoring as: $destination_path"
                ;;
            3)
                echo "Restoration cancelled."
                return 0
                ;;
            *)
                echo -e "${RED}Invalid choice. Restoration cancelled.${NC}"
                return 1
                ;;
        esac
    fi
    # Hint: Move file back and restore permissions
    mv "$source_path" "$destination_path" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Failed to move file to destination${NC}"
        return 1
    fi

    # Restore original permissions
    chmod "$perms" "$destination_path" 2>/dev/null

    # Hint: Remove entry from metadata
    grep -v "^$file_id," "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"

    # Log operation 
    echo "$(date '+%Y-%m-%d %H:%M:%S') [RESTORE] Restored '$original_name' to '$destination_path'" >> "$RECYCLE_BIN_DIR/recyclebin.log"

    echo -e "${GREEN}Successfully restored: ${NC}$original_name → $destination_path"

    return 0
}


#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################

# to improve: right now if you try empty bananas, and bananas doesnt exist, it will say "No matching ID found". But bananas isnt an ID, so it should
# return something else -> now returns "No matching items found for 'INPUT'. Nothing deleted." // y/N both case insensitive // 
# if we got time, let's add a debug-metadata to show if metadata is clean or if there are any ghost entries
# update to delete by name and not only ID or pattern
## UPDATE log to record empty operations
## provide summary of deleted items

empty_recyclebin() {
    local target_id="$1"
    local pattern=""
    local data

    # detect pattern flag and pattern
    if [[ "$target_id" == --pattern=* ]]; then
        pattern="${target_id#--pattern=}"
        target_id=""
    fi

    # load metadata entries (skip first 2 header lines)
    data=$(tail -n +3 "$METADATA_FILE")

    # if user passed an ID, try exact match
    if [[ -n "$target_id" ]]; then
        local match=$(echo "$data" | grep -i "^$target_id," || true)
        if [ -z "$match" ]; then
            echo "No matching items found for '$target_id'. Nothing deleted."
            return 0
        fi
        echo "The following item will be permanently deleted:"
        echo "$match" | cut -d',' -f1,2,4
        echo -n "Are you sure? (y/N): "
    elif [[ -n "$pattern" ]]; then
        local match=$(echo "$data" | grep -i "$pattern" || true)
        if [ -z "$match" ]; then
            echo "No matching items found for '$pattern'. Nothing deleted."
            return 0
        fi
        echo "The following item(s) will be permanently deleted:"
        echo "$match" | cut -d',' -f1,2,4
        echo -n "Are you sure? (y/N): "
    else
        echo -n "Are you sure you want to permanently delete ALL items in the recycle bin? (y/N): "
        match="$data"
    fi

    read confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "Operation canceled." && return 0

    local total_size=0
    local count=0

    echo "Deleted items:"
    while IFS=',' read -r id name path date size type perms owner; do
        rm -rf "$FILES_DIR/$id"
        total_size=$(( total_size + size ))
        count=$(( count + 1 ))

        echo " - $name (ID: $id)"   # Human-readable summary
        echo "$(date '+%Y-%m-%d %H:%M:%S') [EMPTY] Deleted '$name' (ID: $id)" >> "$RECYCLE_BIN_DIR/recyclebin.log"  # LOG
    done <<< "$match"

    # blank line before final summary
    echo

    grep -v -f <(echo "$match" | cut -d',' -f1) "$METADATA_FILE" > "${METADATA_FILE}.tmp"
    mv "${METADATA_FILE}.tmp" "$METADATA_FILE"

    echo "Deleted $count items ($(numfmt --to=iec --suffix=B $total_size))"
    return 0
}



#################################################
# Function: search_recycled
# Description: Searches for files in recycle bin
# Parameters: $1 - search pattern
# Returns: 0 on success
#################################################
# search_recycled features and how to use -> ./recycle_bin.sh search report (shows report in bin)
# date range search -> ./recycle_bin.sh search --date-from=2025-10-20 --date-to=2025-10-30 (date is in YYMMDD format)
# we can combine both name AND date in a single search, for more accurate results ./recycle_bin.sh search report --date-from=2025-10-20 --date-to=2025-10-27 #DONE
# supports --detailed #DONE
# allows single ended ranges (--date-from=XX will show everything from that date forward, --date-to=XX will show everything up until that point) ##DONE
# dates are inclusive: from 2025-10-20 includes the 20th
# the initial function is searching for FULL filename (so if test.txt is in bin, if you search for test you wont get it)
# let's make it search for the name WITHOUT the file extension, for easier handling ## DONE



search_recycled() {
    local name_pattern=""
    local date_from=""
    local date_to=""
    local detailed_mode=false

    # parse arguments in any order
    for arg in "$@"; do
        case "$arg" in
            --date-from=*) date_from="${arg#--date-from=}" ;;
            --date-to=*) date_to="${arg#--date-to=}" ;;
            --detailed) detailed_mode=true ;;
            *) name_pattern="$arg" ;;  # if it’s not a flag, assume it’s a filename search term
        esac
    done

    # if user didn’t specify ANY criteria, nothing to search for
    if [[ -z "$name_pattern" && -z "$date_from" && -z "$date_to" ]]; then
        echo "No search criteria provided."
        return 0
    fi

    # load all metadata (skip header lines)
    local data
    data=$(tail -n +3 "$METADATA_FILE")

    # keep a copy of original data for future reference if needed
    local original_data="$data"

    # strict substring match, case insensitive check
    if [[ -n "$name_pattern" ]]; then
        local filtered=""
        while IFS=',' read -r id name path date size type perms owner; do
            # Convert both to lowercase and check if name contains search term
            if [[ "${name,,}" == *"${name_pattern,,}"* ]]; then
                filtered+="$id,$name,$path,$date,$size,$type,$perms,$owner"$'\n'
            fi
        done <<< "$data"
        data="$filtered"
    fi

    # date ranges are inclusive! >=2025-10-10 includes the 10th
    # YYYY-MM-DD HH:MM:SS allows normal string comparison
    if [[ -n "$date_from" ]]; then
        data=$(echo "$data" | awk -F',' -v df="$date_from" '$4 >= df')
    fi
    if [[ -n "$date_to" ]]; then
        data=$(echo "$data" | awk -F',' -v dt="$date_to" '$4 <= dt')
    fi

    # personalized messages depending on WHY nothing matched
    if [[ -z "$data" ]]; then
        # log stuff
        echo "$(date '+%Y-%m-%d %H:%M:%S') [SEARCH] Search criteria: name='${name_pattern:-'(none)'}' date_from='${date_from:-'(none)'}' date_to='${date_to:-'(none)'}' -- returned 0 items" >> "$RECYCLE_BIN_DIR/recyclebin.log"

        # Filename + date filter -> filename existed but date excluded everything
        if [[ -n "$name_pattern" && (-n "$date_from" || -n "$date_to") ]]; then
            echo "No matching items found for '$name_pattern' in this date range."
        # Only date filter was used -> filename wasn’t part of the search
        elif [[ -n "$date_from" || -n "$date_to" ]]; then
            echo "No matching items found in this date range."
        # Only filename was used -> date filters were not used at all
        else
            echo "No matching items found for '$name_pattern'."
        fi
        return 0
    fi

    echo "=== Search Results ==="
    echo

    local count=0  # used for logging result count

    # table — same as list functions
    if ! $detailed_mode; then
        printf "%-18s | %-20s | %-19s | %-10s\n" "ID" "Name" "Deleted At" "Size"
        printf "%s\n" "--------------------------------------------------------------------------------"
        while IFS=',' read -r id name path date size type perms owner; do
            [[ -z "$id" ]] && continue
            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
            printf "%-18s | %-20s | %-19s | %-10s\n" "${id:0:18}" "$name" "$date" "$human_size"
            ((count++))
        done <<< "$data"
    else
        # DETAILED MODE — same style as list --detailed
        printf "%-18s | %-20s | %-40s | %-19s | %-10s | %-8s | %-10s | %-12s\n" \
               "ID" "Name" "Path" "Deleted At" "Size" "Type" "Perms" "Owner"
        printf "%s\n" "-----------------------------------------------------------------------------------------------------------------------------------------------------"
        while IFS=',' read -r id name path date size type perms owner; do
            [[ -z "$id" ]] && continue
            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
            local short_path=$(printf "%.40s" "$path")  # avoid breaking the table width
            printf "%-18s | %-20s | %-40s | %-19s | %-10s | %-8s | %-10s | %-12s\n" \
                   "$id" "$name" "$short_path" "$date" "$human_size" "$type" "$perms" "$owner"
            ((count++))
        done <<< "$data"
    fi

    # Log search *only after successful output*
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SEARCH] Search criteria: name='${name_pattern:-'(none)'}' date_from='${date_from:-'(none)'}' date_to='${date_to:-'(none)'}' -- returned $count items" >> "$RECYCLE_BIN_DIR/recyclebin.log"

    return 0
}





#################################################
# Function: display_help
# Description: Shows usage information
# Parameters: None
# Returns: 0
#################################################
display_help() {
    cat << EOF
Linux Recycle Bin - Usage Guide

SYNOPSIS:
    $0 [COMMAND] [OPTIONS] [ARGUMENTS]

COMMANDS:

    delete <file1> <file2> ...
        Move one or more files/directories to the recycle bin
        Example: $0 delete "My File.txt"

    list [--detailed] [--sort=name|date|size]
        List contents of the recycle bin
        --detailed   Show full metadata
        --sort=...   Sort by name (A-Z), date (newest first), or size (largest first)
        Example: $0 list --detailed --sort=size

    restore <id>
        Restore the specified item by its unique ID
        Example: $0 restore 1761607543_xpfnr2

    search <pattern> [--detailed] [--date-from=YYYY-MM-DD] [--date-to=YYYY-MM-DD]
        Search for files by filename substring (case insensitive)
        Date filtering is inclusive
        Example: $0 search report --date-from=2025-10-01 --detailed

    empty [<id>] [--pattern=<text>]
        Delete matching items permanently (confirmation required)
        No arguments = delete all items
        Example (delete one):    $0 empty 1761607543_xpfnr2
        Example (pattern match): $0 empty --pattern=log
    
    stats|statistics    
        Show detailed statistics about recycle bin usage
        Example: $0 stats
    
    cleanup|autoclean|auto-clean [--dry-run]
        Run automatic cleanup to remove items older than RETENTION_DAYS (from config)
        --dry-run    Show what would be deleted without removing files
        This is also triggered automatically after delete operations (runs in background).
        Example (manual): $0 cleanup
        Example (preview): $0 cleanup --dry-run
    
    preview <id>
        Show a quick preview of a recycled file.
        - For text files prints first 10 lines.
        - For binary files shows file type info and size.
        Example: $0 preview 1761607543_xpfnr2

    help
        Display this help message

NOTES:
    - Filenames with spaces MUST be quoted.
    - All operations are logged to recyclebin.log.

EOF
    return 0
}

#################################################
# Function: show_statistics
# Description: Displays detailed statistics about recycle bin usage
# Parameters: None
# Returns: 0 on success
#################################################

show_statistics() {
    # Skip if metadata file is empty or missing
    if [ ! -f "$METADATA_FILE" ] || [ $(wc -l < "$METADATA_FILE") -le 2 ]; then
        echo "No statistics available - Recycle bin is empty."
        return 0
    fi  

    # Get data (skip header lines)
    local data=$(tail -n +3 "$METADATA_FILE")
    
    # Calculate basic stats
    local total_items=$(echo "$data" | wc -l)
    local total_size=$(echo "$data" | awk -F',' '{sum += $5} END {print sum}')
    local human_total_size=$(numfmt --to=iec --suffix=B "$total_size" 2>/dev/null)
    
    # Get quota from config
    local quota_mb=$(grep "MAX_SIZE_MB" "$CONFIG_FILE" | cut -d'=' -f2)
    local quota_bytes=$((quota_mb * 1024 * 1024))
    local usage_percent=$(( (total_size * 100) / quota_bytes ))
    
    # Count files vs directories
    local total_files=$(echo "$data" | grep -c ",file,")
    local total_dirs=$(echo "$data" | grep -c ",directory,")
    
    # Get dates
    local newest_item=$(echo "$data" | sort -t',' -k4 | tail -n1)
    local oldest_item=$(echo "$data" | sort -t',' -k4 | head -n1)
    
    # Calculate average size (only for files, not directories)
    local avg_size=$(echo "$data" | grep ",file," | awk -F',' '
        {sum += $5; count++} 
        END {printf "%.0f", count ? sum/count : 0}
    ')
    local human_avg_size=$(numfmt --to=iec --suffix=B "$avg_size" 2>/dev/null)

    # Format output
    cat << EOF
=== Recycle Bin Statistics ===

Storage Usage:
  Total Items:    $total_items
  Total Size:     $human_total_size
  Quota Used:     $usage_percent% of ${quota_mb}MB

Item Breakdown:
  Files:          $total_files
  Directories:    $total_dirs
  Average Size:   $human_avg_size per file

Timeline:
  Newest Item:    $(echo "$newest_item" | cut -d',' -f2,4 | tr ',' ' - ')
  Oldest Item:    $(echo "$oldest_item" | cut -d',' -f2,4 | tr ',' ' - ')

EOF
    return 0
}




#################################################
# Function: auto_cleanup
# Description: Automatically cleans up old items from the recycle bin
# Parameters: $1 - optional "--dry-run" to only show what would be deleted
# Returns: 0 on success
#################################################

auto_cleanup() {
    local dry_run=false
    if [[ "$1" == "--dry-run" ]]; then
        dry_run=true
    fi

    if [ ! -f "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 2 ]; then
        echo "No items to clean (recycle bin is empty)."
        return 0
    fi

    # Read retention days from config (default 30)
    local retention_days
    retention_days=$(grep -E '^RETENTION_DAYS=' "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    retention_days=${retention_days:-30}

    local cutoff=$(date -d "-${retention_days} days" '+%Y-%m-%d %H:%M:%S')

    # Find items older than cutoff (comparison works because of YYYY-MM-DD HH:MM:SS format)
    local matches=$(tail -n +3 "$METADATA_FILE" | awk -F',' -v cutoff="$cutoff" '$4 <= cutoff')

    if [ -z "$matches" ]; then
        echo "No items older than $retention_days days (cutoff: $cutoff)."
        return 0
    fi

    echo "Auto-cleanup: items older than $retention_days days (cutoff: $cutoff):"
    local total_deleted=0
    local total_bytes=0

    while IFS=',' read -r id name path date size type perms owner; do
        [[ -z "$id" ]] && continue
        ((total_deleted++))
        total_bytes=$(( total_bytes + size ))

        if $dry_run; then
            echo "  [DRY-RUN] Would remove: $name (ID: $id) - deleted at $date - size: $(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")"
        else
            rm -rf "$FILES_DIR/$id" 2>/dev/null
            echo "$(date '+%Y-%m-%d %H:%M:%S') [AUTO_CLEAN] Removed '$name' (ID: $id) - originally deleted at $date" >> "$RECYCLE_BIN_DIR/recyclebin.log"
            echo "  Removed: $name (ID: $id) - size: $(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")"
        fi
    done <<< "$matches"

    # Remove entries from metadata (only when not dry-run)
    if ! $dry_run; then
        local idlist
        idlist=$(echo "$matches" | cut -d',' -f1 | tr '\n' '|' | sed 's/|$//')
        awk -F',' -v ids="$idlist" 'BEGIN{n=split(ids,a,"|"); for(i=1;i<=n;i++) del[a[i]]=1} NR<=2{print; next} { if(!($1 in del)) print }' "$METADATA_FILE" > "${METADATA_FILE}.tmp" && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"
    fi

    echo
    if $dry_run; then
        echo "Cleanup summary (dry-run): $total_deleted items would be removed - $(numfmt --to=iec --suffix=B "$total_bytes" 2>/dev/null || echo "${total_bytes}B") would be freed"
    else
        echo "Cleanup summary: $total_deleted items removed - $(numfmt --to=iec --suffix=B "$total_bytes" 2>/dev/null || echo "${total_bytes}B") freed"
    fi

    return 0
}



// ...existing code...
#################################################
# Function: preview_file
# Description: Show a quick preview of a recycled file
#              - For text files: prints first 10 lines
#              - For binary files: displays file(1) type info and size
# Parameters: $1 - unique file ID
# Returns: 0 on success, 1 on failure
#################################################
preview_file() {
    local file_id="$1"
    if [ -z "$file_id" ]; then
        echo -e "${RED}Error: No file ID specified${NC}"
        return 1
    fi

    if [ ! -f "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 2 ]; then
        echo -e "${YELLOW}Recycle bin is empty or metadata missing.${NC}"
        return 1
    fi

    local entry
    entry=$(tail -n +3 "$METADATA_FILE" | grep -m1 "^${file_id}," || true)
    if [ -z "$entry" ]; then
        echo -e "${RED}Error: No entry found for ID '${file_id}'${NC}"
        return 1
    fi

    IFS=',' read -r id original_name original_path deletion_date file_size file_type perms owner <<< "$entry"
    local stored_path="$FILES_DIR/$file_id"

    if [ ! -e "$stored_path" ]; then
        echo -e "${RED}Error: Stored file missing: $stored_path${NC}"
        return 1
    fi

    # Directories cannot be previewed as text
    if [ "$file_type" = "directory" ]; then
        echo -e "${YELLOW}Preview not available: '$original_name' is a directory.${NC}"
        echo "Stored location: $stored_path"
        return 0
    fi

    # Use file(1) to decide text vs binary (check for the word "text" in output)
    local foutput
    foutput=$(file -b --mime-type "$stored_path" 2>/dev/null || file -b "$stored_path" 2>/dev/null)

    if echo "$foutput" | grep -qi 'text'; then
        echo "=== Preview: $original_name (first 10 lines) ==="
        echo
        head -n 10 "$stored_path" 2>/dev/null || echo -e "${YELLOW}(unable to read file contents)${NC}"
        echo
        echo "=== End preview ==="
    else
        # Binary: show file(1) description and size
        local descr
        descr=$(file -b "$stored_path" 2>/dev/null || echo "$foutput")
        local human_size
        human_size=$(numfmt --to=iec --suffix=B "$file_size" 2>/dev/null || echo "${file_size}B")
        echo "File appears to be binary: $original_name"
        echo "Type: $descr"
        echo "Size: $human_size"
    fi

    return 0
}




#################################################
# Function: preview_file
# Description: Show a quick preview of a recycled file
# Parameters: $1 - unique file ID
# Returns: 0 on success, 1 on failure
#################################################
preview_file() {
    local file_id="$1"
    if [ -z "$file_id" ]; then
        echo -e "${RED}Error: No file ID specified${NC}"
        return 1
    fi

    if [ ! -f "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 2 ]; then
        echo -e "${YELLOW}Recycle bin is empty or metadata missing.${NC}"
        return 1
    fi

    local entry
    entry=$(tail -n +3 "$METADATA_FILE" | grep -m1 "^${file_id}," || true)
    if [ -z "$entry" ]; then
        echo -e "${RED}Error: No entry found for ID '${file_id}'${NC}"
        return 1
    fi

    IFS=',' read -r id original_name original_path deletion_date file_size file_type perms owner <<< "$entry"
    local stored_path="$FILES_DIR/$file_id"

    if [ ! -e "$stored_path" ]; then
        echo -e "${RED}Error: Stored file missing: $stored_path${NC}"
        return 1
    fi

    # Directories cannot be previewed as text
    if [ "$file_type" = "directory" ]; then
        echo -e "${YELLOW}Preview not available: '$original_name' is a directory.${NC}"
        echo "Stored location: $stored_path"
        return 0
    fi

    # Use file(1) to decide text vs binary (check for the word "text" in output)
    local foutput=$(file -b --mime-type "$stored_path" 2>/dev/null || file -b "$stored_path" 2>/dev/null)

    if echo "$foutput" | grep -qi 'text'; then
        echo "=== Preview: $original_name (first 10 lines) ==="
        echo
        head -n 10 "$stored_path" 2>/dev/null || echo -e "${YELLOW}(unable to read file contents)${NC}"
        echo
        echo "=== End preview ==="
    else
        # Binary: show file(1) description and size
        local descr
        descr=$(file -b "$stored_path" 2>/dev/null || echo "$foutput")
        local human_size
        human_size=$(numfmt --to=iec --suffix=B "$file_size" 2>/dev/null || echo "${file_size}B")
        echo "File appears to be binary: $original_name"
        echo "Type: $descr"
        echo "Size: $human_size"
    fi

    return 0
}
 



#################################################
# Function: main
# Description: Main program logic
# Parameters: Command line arguments
# Returns: Exit code
#################################################
main() {
    # Initialize recycle bin
    initialize_recyclebin


    # Parse command line arguments
    case "$1" in
        delete)
            shift
            delete_file "$@"
            auto_cleanup &>/dev/null & # Run auto-cleanup in background after deletion
            ;;
        list)
            shift
            list_recycled "$@" ## updated main to check any argument for list_recycled
            ;;
        restore)
            restore_file "$2"
            ;;
        search)
            shift
            search_recycled "$@" ## updated to pass all arguments 
            ;;
        empty)
        shift
            empty_recyclebin "$@" #  all arguments are passed correctly
            ;;
        preview)
            shift
            preview_file "$@"    # preview <id>
            ;;
        stats|statistics)
            show_statistics
            ;;
        cleanup|autoclean|auto-clean)
            shift
            # Manual invocation of auto_cleanup; supports --dry-run
            auto_cleanup "$@"
            ;;
        help|--help|-h)
            display_help
            ;;
        *)
            echo "Invalid option. Use 'help' for usage information."
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
