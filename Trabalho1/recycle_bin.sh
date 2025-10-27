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

empty_recyclebin() {
    local target_id="$1"
    local pattern=""
    local data

    # Detect pattern mode
    if [[ "$target_id" == --pattern=* ]]; then
        pattern="${target_id#--pattern=}"
        target_id=""
    fi

    # Load metadata entries (skip first 2 header lines)
    data=$(tail -n +3 "$METADATA_FILE")

    # If user passed an ID → try to match exactly by ID
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
        # Pattern mode (case-insensitive)
        local match=$(echo "$data" | grep -i "$pattern" || true)
        if [ -z "$match" ]; then
            echo "No matching items found for '$pattern'. Nothing deleted."
            return 0
        fi
        echo "The following item(s) will be permanently deleted:"
        echo "$match" | cut -d',' -f1,2,4
        echo -n "Are you sure? (y/N): "
    else
        # Really delete everything only if NO args provided
        echo -n "Are you sure you want to permanently delete ALL items in the recycle bin? (y/N): "
        match="$data"  # everything
    fi

    read confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && echo "Operation canceled." && return 0

    # Delete matched items
    local total_size=0
    local count=0
    while IFS=',' read -r id name path date size type perms owner; do
        rm -rf "$FILES_DIR/$id"
        total_size=$(( total_size + size ))
        count=$(( count + 1 ))
    done <<< "$match"

    # Rebuild metadata, removing deleted entries
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
search_recycled() {
    # TODO: Implement this function
    local pattern="$1"
    # Your code here
    # Hint: Use grep to search metadata
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
    $0 [OPTION] [ARGUMENTS]

OPTIONS:
    delete <file>      Move file/directory to recycle bin
    list               List all items in recycle bin
    restore <id>       Restore file by ID
    search <pattern>   Search for files by name
    empty              Empty recycle bin permanently
    help               Display this help message

EXAMPLES:
    $0 delete myfile.txt
    $0 list
    $0 restore 1696234567_abc123
    $0 search "*.pdf"
    $0 empty
EOF
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
            ;;
        list)
            shift
            list_recycled "$@" ## updated main to check any argument for list_recycled
            ;;
        restore)
            restore_file "$2"
            ;;
        search)
            search_recycled "$2"
            ;;
        empty)
        shift
            empty_recyclebin "$@" #any argument after empty is passed correctly
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
