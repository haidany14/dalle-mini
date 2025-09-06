#!/usr/bin/env bash
set -euo pipefail

echo "=== Quick Bot-Hub Test (No Dependencies) ==="
echo "This test validates the extracted file structure"
echo

# Check if files were extracted
echo "1. Checking extracted files..."
if [ -d "bot_hub" ]; then
    echo "✓ bot_hub directory exists"
    echo "  Files found:"
    find bot_hub -type f -name "*.py" | head -10 | sed 's/^/    /'
else
    echo "✗ bot_hub directory not found"
    exit 1
fi

echo
echo "2. Checking Python syntax..."
for py_file in bot_hub/*.py bot_hub/*/*.py; do
    if [ -f "$py_file" ]; then
        if python3 -m py_compile "$py_file" 2>/dev/null; then
            echo "✓ $py_file - syntax OK"
        else
            echo "✗ $py_file - syntax error"
        fi
    fi
done

echo
echo "3. Checking configuration files..."
for cfg in bot_hub/config/*.yaml bot_hub/config/*.json; do
    if [ -f "$cfg" ]; then
        echo "✓ Found: $cfg"
    fi
done

echo
echo "4. File structure summary:"
echo "  Main modules:"
find bot_hub -name "*.py" -maxdepth 1 | wc -l | xargs echo "    -" "files"
echo "  Security module:"
find bot_hub/security -name "*.py" 2>/dev/null | wc -l | xargs echo "    -" "files"
echo "  Telegram module:"
find bot_hub/telegram -name "*.py" 2>/dev/null | wc -l | xargs echo "    -" "files"
echo "  Config files:"
find bot_hub/config -name "*" -type f 2>/dev/null | wc -l | xargs echo "    -" "files"

echo
echo "=== Quick test complete ==="
echo
echo "Note: To run the full application, you need to install dependencies:"
echo "  pip install fastapi uvicorn httpx aiofiles redis pyyaml python-multipart"
echo "  Then run: uvicorn bot_hub.main:app --host 0.0.0.0 --port 8080"