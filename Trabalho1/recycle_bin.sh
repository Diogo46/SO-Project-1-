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
VERSION="1.0" ## update version when needed
VERBOSE=false


# Color Codes 
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

#################################################
# Function: version_command
# Description: Prints tool version and basic env info
# Parameters: None
# Returns: 0
#################################################

version_command() {
    echo "Linux Recycle Bin - Version $VERSION"
    echo "Metadata: $METADATA_FILE"
    echo "Files dir: $FILES_DIR"
    echo "Config: $CONFIG_FILE"
    return 0
}

#################################################
# Function: config_command
# Description: Shows or updates configuration
# Parameters:
#   show
#   set quota <MB>
#   set retention <DAYS>
# Returns: 0 on success, 1 on failure
#################################################

config_command() {
    local action="$1"
    local key="$2"
    local value="$3"

    # Ensure config exists
    [ -f "$CONFIG_FILE" ] || {
        echo "MAX_SIZE_MB=1024" > "$CONFIG_FILE"
        echo "RETENTION_DAYS=30" >> "$CONFIG_FILE"
    }

    # Helper to read current values
    local cur_quota cur_retention
    cur_quota=$(grep -E '^MAX_SIZE_MB=' "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    cur_retention=$(grep -E '^RETENTION_DAYS=' "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    cur_quota=${cur_quota:-1024}
    cur_retention=${cur_retention:-30}

    case "$action" in
        show|"")
            echo "Current configuration:"
            echo "  Quota (MAX_SIZE_MB):     $cur_quota MB"
            echo "  Retention (RETENTION_DAYS): $cur_retention days"
            return 0
            ;;
        set)
            case "$key" in
                quota)
                    # Must be a positive integer
                    if [[ ! "$value" =~ ^[0-9]+$ ]] || [ "$value" -le 0 ]; then
                        echo "Invalid quota value. Use a positive integer in MB."
                        return 1
                    fi
                    if grep -qE '^MAX_SIZE_MB=' "$CONFIG_FILE"; then
                        sed -i "s/^MAX_SIZE_MB=.*/MAX_SIZE_MB=$value/" "$CONFIG_FILE"
                    else
                        echo "MAX_SIZE_MB=$value" >> "$CONFIG_FILE"
                    fi
                    echo "Updated quota to $value MB."
                    ;;
                retention)
                    if [[ ! "$value" =~ ^[0-9]+$ ]] || [ "$value" -le 0 ]; then
                        echo "Invalid retention value. Use a positive integer in days."
                        return 1
                    fi
                    if grep -qE '^RETENTION_DAYS=' "$CONFIG_FILE"; then
                        sed -i "s/^RETENTION_DAYS=.*/RETENTION_DAYS=$value/" "$CONFIG_FILE"
                    else
                        echo "RETENTION_DAYS=$value" >> "$CONFIG_FILE"
                    fi
                    echo "Updated retention to $value days."
                    ;;
                *)
                    echo "Usage:"
                    echo "  $0 config show"
                    echo "  $0 config set quota <MB>"
                    echo "  $0 config set retention <DAYS>"
                    return 1
                    ;;
            esac
            # Show new values after update
            echo "New configuration:"
            echo "  Quota (MAX_SIZE_MB):     $(grep -E '^MAX_SIZE_MB=' "$CONFIG_FILE" | cut -d'=' -f2) MB"
            echo "  Retention (RETENTION_DAYS): $(grep -E '^RETENTION_DAYS=' "$CONFIG_FILE" | cut -d'=' -f2) days"
            return 0
            ;;
        *)
            echo "Usage:"
            echo "  $0 config show"
            echo "  $0 config set quota <MB>"
            echo "  $0 config set retention <DAYS>"
            return 1
            ;;
    esac
}



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
# Description: Generates a shell-safe unique ID (A–Z, a–z, 0–9, _ or - only)
# Returns: Prints unique ID to stdout
#################################################
generate_unique_id() {
    # Base: epoch seconds + random alnum block
    # LC_ALL=C makes tr's ranges portable; head -c avoids UUOC
    local ts rand id
    ts="$(date +%s)"
    rand="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 10)"
    id="${ts}_${rand}"

    # Enforce safe charset: keep only [A-Za-z0-9_-]
    # (If anything odd slips in from environment/locale, it gets dropped.)
    id="$(printf '%s' "$id" | LC_ALL=C tr -cd 'A-Za-z0-9_-')"

    # Last-resort fallback so we never emit empty
    [ -z "$id" ] && id="$ts"

    printf '%s\n' "$id"
}


#################################################
# Function: delete_file
# Description: Moves file/directory to recycle bin
# Parameters: $@ - path(s) to file(s)/directory(ies)
# Returns: 0 on overall success (per-item errors are reported/logged)
#################################################
delete_file() {
    if [ "$#" -eq 0 ]; then
        echo -e "${RED}Error: No file specified${NC}"
        debug "Aborted delete: no file specified"
        return 1
    fi

    for file_path in "$@"; do
        debug "Attempting to delete '$file_path'"
        [[ -z "$file_path" ]] && debug "Skipping empty file argument" && continue 

        # Prevent deleting the recycle bin itself
        if [[ "$file_path" == "$RECYCLE_BIN_DIR"* ]]; then
            echo -e "${RED}Error: Cannot delete the recycle bin itself!${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [DELETE] Blocked attempt to delete recycle bin: $file_path" >> "$RECYCLE_BIN_DIR/recyclebin.log"
            debug "Blocked delete: attempt to delete recycle bin itself"
            continue
        fi

        # Check if file exists
        if [ ! -e "$file_path" ]; then
            echo -e "${RED}Error: '$file_path' does not exist.${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [DELETE] Failed: '$file_path' not found" >> "$RECYCLE_BIN_DIR/recyclebin.log"
            debug "Skipped delete: file not found"
            continue
        fi

        # Check permissions (read/write on parent dir)
        if [ ! -r "$file_path" ] || [ ! -w "$(dirname "$file_path")" ]; then
            echo -e "${RED}Error: No permission to delete '$file_path'${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [DELETE] Permission denied for '$file_path'" >> "$RECYCLE_BIN_DIR/recyclebin.log"
            debug "Skipped delete: insufficient permissions on '$file_path'"
            continue
        fi

        # Gather metadata
        local original_name original_path deletion_date file_size file_type original_permissions original_owner
        original_name=$(basename "$file_path")
        original_path=$(dirname "$file_path")
        deletion_date=$(date '+%Y-%m-%d %H:%M:%S')
        file_size=$(stat -c %s "$file_path")
        file_type=$([ -d "$file_path" ] && echo "directory" || echo "file")
        original_permissions=$(stat -c %a "$file_path")
        original_owner=$(stat -c %U:%G "$file_path")

        local file_id
        file_id=$(generate_unique_id)

        debug "Metadata collected: name='$original_name', size=${file_size}B, type=$file_type, id=$file_id"

        # Move to storage
        if ! mv "$file_path" "$FILES_DIR/$file_id" 2>/dev/null; then
            echo -e "${RED}Error: Failed to move '$file_path' to recycle bin${NC}"
            echo "$(date '+%Y-%m-%d %H:%M:%S') [DELETE] Failed to move '$file_path' to storage" >> "$RECYCLE_BIN_DIR/recyclebin.log"
            debug "Move failed: mv '$file_path' → '$FILES_DIR/$file_id'"
            continue
        fi

        debug "File successfully moved into storage as ID $file_id"

        # Append metadata
        echo "$file_id,$original_name,$original_path,$deletion_date,$file_size,$file_type,$original_permissions,$original_owner" >> "$METADATA_FILE"

        # Log (persistent)
        echo "$(date '+%Y-%m-%d %H:%M:%S') [DELETE] Deleted '$original_name' (ID: $file_id)" >> "$RECYCLE_BIN_DIR/recyclebin.log"

        # User feedback
        echo -e "${GREEN}'$original_name' moved to Recycle Bin (ID: $file_id)${NC}"
        debug "Delete operation completed for '$original_name' (ID: $file_id)"
    done

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
    local reverse_mode=false

    for arg in "$@"; do
        [[ -z "$arg" ]] && debug "Skipping empty flag" && continue
        case "$arg" in
            --detailed)
                detailed_mode=true
                ;;
            --sort=*)
                sort_option="${arg#--sort=}"
                ;;
            --reverse|-r)
                reverse_mode=true
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$arg'${NC}"
                debug "User entered invalid option: $arg"
                echo "Valid options: --detailed, --sort=name|date|size, --reverse|-r"
                return 1
                ;;
        esac
    done

    debug "List requested with sort='$sort_option', reverse=$reverse_mode, detailed=$detailed_mode"

    case "$sort_option" in
        none|name|date|size) ;;
        *)
            echo -e "${RED}Error: Invalid sort option '$sort_option'${NC}"
            debug "User entered invalid sort option: $sort_option"
            return 1
            ;;
    esac

    if [ ! -s "$METADATA_FILE" ] || [ "$(wc -l < "$METADATA_FILE")" -le 2 ]; then
        echo "Recycle bin is empty."
        debug "Metadata file is empty — nothing to list"
        return 0
    fi

    echo "=== Recycle Bin Contents ==="
    echo

    local data
    data=$(tail -n +3 "$METADATA_FILE")
    debug "Loaded $(echo "$data" | wc -l) recycle bin entries from metadata"

    case "$sort_option" in
        name)
            debug "Sorting by name (A-Z, case-insensitive)"
            data=$(echo "$data" | LC_ALL=C sort -t ',' -f -k2,2 -s)
            ;;
        date)
            debug "Sorting by date (newest first)"
            data=$(echo "$data" | LC_ALL=C sort -t ',' -k4,4r -s)
            ;;
        size)
            debug "Sorting by size (largest first)"
            data=$(echo "$data" | LC_ALL=C sort -t ',' -k5,5nr -s)
            ;;
    esac

    if [ "$reverse_mode" = true ]; then
        debug "Reverse mode enabled — reversing output order"
        data=$(echo "$data" | tac)
    fi

    local total_size=0
    local count=0

    if ! $detailed_mode; then
        printf "%-18s | %-20s | %-19s | %-10s\n" "ID (first 18 chars)" "Name" "Deleted At" "Size"
        printf "%s\n" "--------------------------------------------------------------------------------"
        while IFS=',' read -r id name path date size type perms owner; do
            [[ -z "$id" ]] && continue
            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
            printf "%-18s… | %-20s | %-19s | %-10s\n" "${id:0:18}" "$name" "$date" "$human_size"
            total_size=$(( total_size + size ))
            count=$(( count + 1 ))
        done <<< "$data"
        echo
        echo "(Tip: use --detailed to view full IDs)"
    else
        debug "Showing results in detailed mode"
        printf "%-21s | %-20s | %-40s | %-19s | %-10s | %-8s | %-10s | %-12s\n" \
               "ID" "Name" "Path" "Deleted At" "Size" "Type" "Perms" "Owner"
        printf "%s\n" "-----------------------------------------------------------------------------------------------------------------------------------------------------"
        while IFS=',' read -r id name path date size type perms owner; do
            [[ -z "$id" ]] && continue
            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
            local short_path=$(printf "%.40s" "$path")
            printf "%-18s | %-20s | %-40s | %-19s | %-10s | %-8s | %-10s | %-12s\n" \
                   "$id" "$name" "$short_path" "$date" "$human_size" "$type" "$perms" "$owner"
            total_size=$(( total_size + size ))
            count=$(( count + 1 ))
        done <<< "$data"
    fi

    echo
    debug "Final count: $count items, total size = $total_size bytes"
    echo "Total items: $count"
    echo "Total size:  $(numfmt --to=iec --suffix=B "$total_size" 2>/dev/null)"
    return 0
}




#################################################
# Function: restore_file
# Description: Restores file from recycle bin by ID or name pattern
# Parameters:
#   --id <ID>     -> Force exact ID match
#   <pattern>     -> Restore by filename substring (case-insensitive)
# Returns: 0 on success, 1 on failure
#################################################
restore_file() {
    # Skip empty or accidental arg
    [[ -z "$1" ]] && debug "Skipping empty restore argument" && return 1

    local force_id=false
    local file_id=""

    # Parse flags (order flexible)
    for arg in "$@"; do
        case "$arg" in
            --id)  force_id=true ;;  # force exact ID restore
            *)     file_id="$arg"  ;;  # treat ANY other arg as target
        esac
    done

    # Basic safety
    if [[ -z "$file_id" ]]; then
        echo -e "${RED}Error: No file ID or pattern specified${NC}"
        debug "Restore aborted: missing argument"
        return 1
    fi

    if [[ ! -f "$METADATA_FILE" || $(wc -l < "$METADATA_FILE") -le 2 ]]; then
        echo -e "${YELLOW}Recycle bin is empty or metadata missing.${NC}"
        debug "Restore aborted: empty metadata"
        return 1
    fi

    # Clean CR + spaces
    file_id="${file_id%%[[:space:]]}"
    file_id="${file_id//$'\r'/}"

    # --- Auto-detect if argument looks like a valid ID (timestamp_10chars) ---
    if [[ "$file_id" =~ ^[0-9]{10}_[A-Za-z0-9]{10}$ ]]; then
        debug "Detected ID pattern '$file_id' — forcing ID mode"
        force_id=true
    fi

    debug "Restore request: '$file_id' | force_id=$force_id"

    local entry=""
    if $force_id; then
        # Exact ID restore
        entry=$(
            tail -n +3 "$METADATA_FILE" \
            | tr -d '\r' \
            | awk -F',' -v id="$file_id" 'tolower($1) == tolower(id) { print; exit }'
        )
        if [[ -z "$entry" ]]; then
            echo -e "${RED}Error: No matching entry found for exact ID '$file_id'${NC}"
            debug "No entry for exact ID '$file_id'"
            return 1
        fi
    else
        # PATTERN search -- name-based, case-insensitive substring
        debug "Running pattern match for '$file_id'"
        entry=$(tail -n +3 "$METADATA_FILE" | awk -F',' -v term="${file_id,,}" 'tolower($2) ~ term {print}')
        if [[ -z "$entry" ]]; then
            echo -e "${RED}No matching items found for pattern '$file_id'${NC}"
            debug "No match on pattern '$file_id'"
            return 1
        fi

        # If multiple results, interactive choice
        if [[ $(echo "$entry" | wc -l) -gt 1 ]]; then
            echo "Multiple matches found:"
            IFS=$'\n' read -r -d '' -a results <<< "$entry"
            for i in "${!results[@]}"; do
                local name=$(echo "${results[$i]}" | cut -d',' -f2)
                printf " [%d] %s\n" "$((i+1))" "$name"
            done
            read -p "Select an entry to restore (1-${#results[@]}): " choice
            (( choice >= 1 && choice <= ${#results[@]} )) || {
                echo "Invalid choice. Aborting."
                debug "Restore aborted: invalid user selection"
                return 1
            }
            entry="${results[$((choice-1))]}"
        fi
    fi

    # Read metadata fields properly
    IFS=',' read -r file_id original_name original_path deletion_date file_size file_type perms owner <<< "$entry"
    local source_path="$FILES_DIR/$file_id"
    local destination_path="$original_path/$original_name"

    [[ ! -e "$source_path" ]] && echo -e "${RED}Error: File missing in storage${NC}" \
        && debug "Stored file missing for ID '$file_id'" && return 1

    [[ ! -d "$original_path" ]] && mkdir -p "$original_path"

    mv "$source_path" "$destination_path" 2>/dev/null || {
        echo -e "${RED}Failed to restore file${NC}"
        debug "mv failed from '$source_path' to '$destination_path'"
        return 1
    }

    chmod "$perms" "$destination_path" 2>/dev/null
    awk -F',' -v id="$file_id" 'NR<=2 {print; next} $1 != id' "$METADATA_FILE" > "${METADATA_FILE}.tmp" \
        && mv "${METADATA_FILE}.tmp" "$METADATA_FILE"

    echo "$(date '+%Y-%m-%d %H:%M:%S') [RESTORE] Restored '$original_name'" >> "$RECYCLE_BIN_DIR/recyclebin.log"
    echo -e "${GREEN}Restored: ${NC}$original_name → $destination_path"
    debug "Restore complete for '$original_name' (ID $file_id)"
    return 0
}


#################################################
# Function: empty_recyclebin
# Description: Permanently deletes all items
# Parameters: None
# Returns: 0 on success
#################################################


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


search_recycled() {
    # Silent skip if empty arg accidentally passed (from verbose cleanup or user mistake)
    [[ -z "$1" ]] && return 0

    local name_pattern=""
    local date_from=""
    local date_to=""
    local detailed_mode=false

    for arg in "$@"; do
        [[ -z "$arg" ]] && continue  # silent skip
        case "$arg" in
            --date-from=*) date_from="${arg#--date-from=}" ;;
            --date-to=*)   date_to="${arg#--date-to=}" ;;
            --detailed)    detailed_mode=true ;;
            *)             name_pattern="$arg" ;;
        esac
    done

    debug "Search requested: name='$name_pattern', from='$date_from', to='$date_to', detailed=$detailed_mode"

    if [[ -z "$name_pattern" && -z "$date_from" && -z "$date_to" ]]; then
        echo "No search criteria provided."
        debug "Search aborted — no valid search criteria"
        return 0
    fi

    local data
    data=$(tail -n +3 "$METADATA_FILE" | tr -d '\r')

    debug "Loaded $(echo "$data" | wc -l) items for searching"

    if [[ -n "$name_pattern" ]]; then
        debug "Filtering by name pattern: $name_pattern"
        local filtered=""
        while IFS=',' read -r id name path date size type perms owner; do
            if [[ "${name,,}" == *"${name_pattern,,}"* ]]; then
                filtered+="$id,$name,$path,$date,$size,$type,$perms,$owner"$'\n'
            fi
        done <<< "$data"
        data="$filtered"
    fi

    if [[ -n "$date_from" ]]; then
        debug "Applying date-from filter: $date_from (inclusive)"
        data=$(echo "$data" | awk -F',' -v df="$date_from" '$4 >= df')
    fi
    if [[ -n "$date_to" ]]; then
        debug "Applying date-to filter: $date_to (inclusive)"
        data=$(echo "$data" | awk -F',' -v dt="$date_to" '$4 <= dt')
    fi

    if [[ -z "$data" ]]; then
        debug "No results matched filters"
        if [[ -n "$name_pattern" && (-n "$date_from" || -n "$date_to") ]]; then
            echo "No matching items found for '$name_pattern' in this date range."
        elif [[ -n "$date_from" || -n "$date_to" ]]; then
            echo "No matching items found in this date range."
        else
            echo "No matching items found for '$name_pattern'."
        fi
        return 0
    fi

    echo "=== Search Results ==="
    echo

    local count=0
    if ! $detailed_mode; then
        printf "%-18s | %-20s | %-19s | %-10s\n" "ID" "Name" "Deleted At" "Size"
        printf "%s\n" "--------------------------------------------------------------------------------"
        while IFS=',' read -r id name path date size type perms owner; do
            [[ -z "$id" ]] && continue
            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
            printf "%-18s… | %-20s | %-19s | %-10s\n" "${id:0:18}" "$name" "$date" "$human_size"
            ((count++))
        done <<< "$data"
        echo
        echo "(Tip: use --detailed to view full IDs)"
    else
        printf "%-18s | %-20s | %-40s | %-19s | %-10s | %-8s | %-10s | %-12s\n" \
               "ID" "Name" "Path" "Deleted At" "Size" "Type" "Perms" "Owner"
        printf "%s\n" "-----------------------------------------------------------------------------------------------------------------------------------------------------"
        while IFS=',' read -r id name path date size type perms owner; do
            [[ -z "$id" ]] && continue
            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
            local short_path
            short_path=$(printf "%.40s" "$path")
            printf "%-18s | %-20s | %-40s | %-19s | %-10s | %-8s | %-10s | %-12s\n" \
                   "$id" "$name" "$short_path" "$date" "$human_size" "$type" "$perms" "$owner"
            ((count++))
        done <<< "$data"
    fi

    debug "Search complete — matched $count items"
    return 0
}


#################################################
# Function: interactive_menu
# Description: Provides a text-based menu for users
#              to manage the recycle bin interactively.
# Parameters: None
# Returns: 0 on exit
#################################################
interactive_menu() {
    clear
    echo "==============================================="
    echo "         Linux Recycle Bin - Interactive Mode  "
    echo "==============================================="
    echo "Version: $VERSION"
    echo "Recycle Bin: $RECYCLE_BIN_DIR"
    echo

    # Strict yes/no helper: accepts only y or n (case-insensitive). Empty is invalid.
    ask_yes_no() {
        local prompt="$1"
        local ans
        while true; do
            read -p "$prompt (y/N): " ans
            # Normalize to lowercase and trim leading/trailing whitespace
            ans="$(echo -n "$ans" | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            case "$ans" in
                y) return 0 ;;   # yes
                n) return 1 ;;   # no
                *) echo -e "${YELLOW}Invalid input. Please answer with y or n.${NC}" 1>&2 ;;
            esac
        done
    }

    while true; do
        echo "Choose an option:"
        echo " 1) Delete a file"
        echo " 2) List recycled items"
        echo " 3) Restore a file"
        echo " 4) Search files"
        echo " 5) Empty recycle bin"
        echo " 6) Show statistics"
        echo " 7) Auto-clean old items"
        echo " 8) Preview a file"
        echo " 9) Show configuration"
        echo "10) Change configuration"
        echo "11) Show help"
        echo " 0) Exit"
        echo

        read -p "Enter your choice [0-11]: " choice
        echo

        case "$choice" in
            1)
                read -p "Enter the full path(s) of the file(s) to delete: " -a files
                delete_file "${files[@]}"
                ;;
            2)
                if ask_yes_no "Show detailed view?"; then
                    list_recycled --detailed
                else
                    list_recycled
                fi
                ;;
            3)
                read -p "Enter filename or --id <ID> to restore: " args
                restore_file $args
                ;;
            4)
                read -p "Enter search term: " pattern
                if ask_yes_no "Filter by date range?"; then
                    read -p "From date (YYYY-MM-DD): " from
                    read -p "To date (YYYY-MM-DD): " to
                    search_recycled "$pattern" --date-from="$from" --date-to="$to"
                else
                    search_recycled "$pattern"
                fi
                ;;
            5)
                read -p "Enter ID or --pattern=<text> (leave blank for ALL): " arg
                empty_recyclebin "$arg"
                ;;
            6)
                show_statistics
                ;;
            7)
                if ask_yes_no "Run dry-run mode first?"; then
                    auto_cleanup --dry-run
                else
                    auto_cleanup
                fi
                ;;
            8)
                read -p "Enter file ID to preview: " fid
                preview_file "$fid"
                ;;
            9)
                config_command show
                ;;
            10)
                echo "Select the configuration to change:"
                echo " [1] Quota"
                echo " [2] Retention"
                read -p "Enter your choice [1-2]: " cfg_choice

                case "$cfg_choice" in
                    1)
                        read -p "Enter new quota value (in MB): " value
                        config_command set quota "$value"
                        ;;
                    2)
                        read -p "Enter new retention value (in days): " value
                        config_command set retention "$value"
                        ;;
                    *)
                        echo -e "${RED}Invalid input. Please choose either 1 or 2.${NC}"
                        ;;
                esac
                ;;
            11)
                display_help
                ;;
            0)
                echo "Exiting interactive mode. Goodbye!"
                sleep 1
                break
                ;;
            *)
                echo -e "${RED}Invalid option. Please choose between 0 and 11.${NC}"
                ;;
        esac

        echo
        read -p "Press Enter to continue..." temp
        clear
        echo "==============================================="
        echo "       Linux Recycle Bin - Interactive Mode    "
        echo "==============================================="
        echo
    done
}


#################################################
# Function: display_help
# Description: Shows usage information
# Parameters: None
# Returns: 0
#################################################
display_help() {
    local cur_quota cur_retention
    cur_quota=$(grep -E '^MAX_SIZE_MB=' "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    cur_retention=$(grep -E '^RETENTION_DAYS=' "$CONFIG_FILE" 2>/dev/null | cut -d'=' -f2)
    cur_quota=${cur_quota:-1024}
    cur_retention=${cur_retention:-30}

    cat << EOF
Linux Recycle Bin - Usage Guide (Version $VERSION)
==================================================

SYNOPSIS:
    $0 [COMMAND] [OPTIONS] [ARGUMENTS]

COMMANDS:

    delete <file1> <file2> ...
        Move one or more files/directories to the recycle bin.
        Example: $0 delete "My File.txt"

    list [--detailed] [--sort=name|date|size] [--reverse]
        List contents of the recycle bin.
        --detailed   Show full metadata
        --sort=...   Sort by name (A-Z), date (newest first), or size (largest first)
        --reverse    Reverse the current sort order
        Example: $0 list --detailed --sort=size

    restore <pattern>
        Restore file by matching its NAME (case-insensitive substring match).
        Example: $0 restore report

    restore --id <ID>
        Restore file by exact UNIQUE ID (force ID mode — only restores that specific ID).
        Example: $0 restore --id 1761764214_N5atvz8hox

    search <pattern> [--detailed] [--date-from=YYYY-MM-DD] [--date-to=YYYY-MM-DD]
        Search files by filename substring (case-insensitive).
        Date filtering is inclusive.
        Example: $0 search report --date-from=2025-10-01 --detailed

    empty [<id>] [--pattern=<text>]
        Permanently delete matching items (confirmation required).
        No arguments = delete all items.
        Example (delete one):    $0 empty 1761767543_xpfnr2
        Example (pattern match): $0 empty --pattern=log

    stats|statistics
        Show detailed statistics about recycle bin usage.
        Example: $0 stats

    preview <id>
        Show a quick preview of a recycled file.
        Example: $0 preview 1761767543_xpfnr2

    cleanup|autoclean|auto-clean [--dry-run]
        Manually trigger auto-cleanup of expired items (older than RETENTION_DAYS).
        --dry-run    Show what would be deleted, without actually deleting.
        Example: $0 cleanup --dry-run

    version
        Show version and important file paths.
        Example: $0 version

    config show
        Display current configuration (quota + retention).
        Example: $0 config show

    config set quota <MB>
        Update max allowed recycle bin size.
        Example: $0 config set quota 2048

    config set retention <DAYS>
        Update how many days deleted files are kept before cleanup.
        Example: $0 config set retention 45

    help
        Display this help message.

--------------------------------------------------
INTERACTIVE MENU MODE
--------------------------------------------------

    You can manage the recycle bin interactively through a simple menu system.

    To launch it:
        $0 interactive
        or
        $0 menu

    Inside the menu, you can:
        [1] Delete a file or folder
        [2] List all recycled items
        [3] Restore files by name or ID
        [4] Search files (with optional date filters)
        [5] Empty the recycle bin
        [6] Show usage statistics
        [7] Auto-clean old files
        [8] Preview a recycled file
        [9] Show current configuration
       [10] Change configuration (Quota or Retention)
       [11] View help
        [0] Exit the menu

    All yes/no prompts require explicit answers ("y" or "n").
    Invalid inputs will display a yellow warning message.

NOTES:
    - Filenames with spaces MUST be quoted.
    - All operations are logged to recyclebin.log.
    - Version: $VERSION | Retention: ${cur_retention} days | Quota: ${cur_quota} MB

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
# Function: debug
# Description: Prints internal debug information only when --verbose is enabled.
#              Safe to call from anywhere — has zero effect if VERBOSE=false.
# Parameters: $1 - The message to print in debug mode.
# Returns: 0 always (no failure mode, it's a passive helper).
#################################################

debug() {
    if [ "${VERBOSE:-false}" = true ]; then
        echo -e "${YELLOW}[DEBUG] $1${NC}" >&2
    fi
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

    # verbose mode

    for arg in "$@"; do
        if [[ "$arg" == "--verbose" ]]; then
            VERBOSE=true
            # Remove it from the argument list so subcommands don't get confused
            set -- "${@/--verbose}"
            break
        fi
    done


    debug "Verbose mode enabled."



    # Parse command line arguments
    case "$1" in
        delete)
            shift
            delete_file "$@"
            auto_cleanup &>/dev/null & # Run auto-cleanup in background after deletion
            ;;
        version|--version|-v)
            version_command
            ;;
        config|--config)
            shift
            config_command "$@"
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
        interactive|menu)
            interactive_menu
            ;;

        *)
            echo "Invalid option. Use 'help' for usage information."
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
