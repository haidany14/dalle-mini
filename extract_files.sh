#!/usr/bin/env bash
set -euo pipefail

echo "=== Extracting Bot-Hub files from bundles ==="

# Function to extract files from a bundle
extract_bundle() {
    local bundle_file="$1"
    echo "Processing $bundle_file..."
    
    # Read the bundle and extract files
    while IFS= read -r line; do
        if [[ "$line" == "PATH: "* ]]; then
            current_path="${line#PATH: }"
        elif [[ "$line" == "MODE: "* ]]; then
            current_mode="${line#MODE: }"
        elif [[ "$line" == "-----8<----- START CONTENT -----8<-----" ]]; then
            # Start capturing content
            content=""
            while IFS= read -r content_line; do
                if [[ "$content_line" == "-----8<----- END CONTENT -----8<-----" ]]; then
                    break
                fi
                if [[ -n "$content" ]]; then
                    content+="\n"
                fi
                content+="$content_line"
            done
            
            # Create directory if needed
            dir=$(dirname "$current_path")
            if [[ -n "$dir" && "$dir" != "." ]]; then
                mkdir -p "$dir"
            fi
            
            # Write content to file
            echo -e "$content" > "$current_path"
            
            # Set permissions
            if [[ "$current_mode" == "0755" ]]; then
                chmod 755 "$current_path"
            else
                chmod 644 "$current_path"
            fi
            
            echo "  Created: $current_path (mode: $current_mode)"
        fi
    done < "$bundle_file"
}

# Extract all bundle files
for bundle in BH_FULL.part*.txt; do
    if [[ -f "$bundle" ]]; then
        extract_bundle "$bundle"
    fi
done

echo "=== Extraction complete ==="
echo "Directory structure:"
find . -name "bot_hub" -type d | head -1 | xargs -I {} find {} -type f | sort