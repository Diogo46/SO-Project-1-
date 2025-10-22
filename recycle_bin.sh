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
    # TODO: Implement this function
    local detailed_mode=false

    # --- Check if the user passed the --detailed flag ---
    if [ "$1" == "--detailed" ]; then
        detailed_mode=true
    fi

    # --- Handle empty recycle bin ---
    if [ ! -s "$METADATA_FILE" ] || [ $(wc -l < "$METADATA_FILE") -le 2 ]; then
        echo "Recycle bin is empty."
        return 0
    fi

    echo "=== Recycle Bin Contents ==="
    echo


    # Your code here
    # Skip the header line and read entries 
    # We'll use tail -n +3 because our metadata file has 2 header lines
    local total_size=0
    local count=0

     if [ "$detailed_mode" = false ]; then
        # ---------- NORMAL MODE ----------
        printf "%-10s | %-20s | %-19s | %-10s\n" "ID" "Name" "Deleted At" "Size"
        printf "%s\n" "---------------------------------------------------------------------"

        while IFS=',' read -r id name path date size type perms owner; do
            # Skip empty or header lines
            [[ "$id" == "ID" || -z "$id" ]] && continue

            # Convert size to human-readable format
            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")

            printf "%-10s | %-20s | %-19s | %-10s\n" "${id:0:8}" "$name" "$date" "$human_size"

            ((total_size+=size))
            ((count++))
        done < <(tail -n +3 "$METADATA_FILE")
    else
        # ---------- DETAILED MODE ----------
        while IFS=',' read -r id name path date size type perms owner; do
            [[ "$id" == "ID" || -z "$id" ]] && continue

            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")

            echo "-----------------------------"
            echo "ID:          $id"
            echo "Name:        $name"
            echo "Path:        $path"
            echo "Deleted At:  $date"
            echo "Size:        $human_size"
            echo "Type:        $type"
            echo "Permissions: $perms"
            echo "Owner:       $owner"
            echo
            ((total_size+=size))
            ((count++))
        done
    fi

    # --- Display totals ---
    local total_human=$(numfmt --to=iec --suffix=B "$total_size" 2>/dev/null || echo "${total_size}B")

    echo
    echo "Total items: $count"
    echo "Total size:  $total_human"
    # Hint: Read metadata file and format output
    # Hint: Use printf for formatted table
    # Hint: Skip header line
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
    # Hint: Get original path from metadata
    # Hint: Check if original path exists
    # Hint: Move file back and restore permissions
    # Hint: Remove entry from metadata
    return 0
}


#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################
empty_recyclebin() {
    # TODO: Implement this function
    # Your code here
    # Hint: Ask for confirmation
    # Hint: Delete all files in FILES_DIR
    # Hint: Reset metadata file
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
            list_recycled
            ;;
        restore)
            restore_file "$2"
            ;;
        search)
            search_recycled "$2"
            ;;
        empty)
            empty_recyclebin
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
