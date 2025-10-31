#!/bin/bash

# Set explicit metadata path (adjust if your structure is different)
METADATA_FILE="$HOME/.recycle_bin/metadata.db"

# Check if file exists first
if [ ! -f "$METADATA_FILE" ]; then
    echo "Error: Metadata file not found at $METADATA_FILE"
    exit 1
fi

# Backup
cp "$METADATA_FILE" "$METADATA_FILE.bak" || {
    echo "Error: Failed to create backup."
    exit 1
}

# Clean invalid lines (remove debug or malformed entries)
awk -F',' '
NR<=2 { print; next }
$1 ~ /^[0-9]{10}_[A-Za-z0-9_-]+$/ { print }
' "$METADATA_FILE.bak" > "$METADATA_FILE"

echo "✅ Metadata cleaned successfully."
echo "Backup saved as: $METADATA_FILE.bak"
