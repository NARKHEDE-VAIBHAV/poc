#!/usr/bin/env bash
#Affected: latest main branch (tested May 2026)


set -euo pipefail

WORKDIR="$(mktemp -d)"
REPO="$WORKDIR/skills"
WS="$WORKDIR/workspace"
REPORT="$WORKDIR/deep_trace_perm_report.txt"

echo "[+] Workdir: $WORKDIR"
echo "[+] Report:  $REPORT"

git clone --depth 1 https://github.com/browserbase/skills.git "$REPO" >/dev/null
cd "$REPO"

{
echo "Browserbase skills deep trace permission/security test"
echo "Workdir: $WORKDIR"
echo

echo "================================================================================"
echo "[1] Confirm vulnerable code locations"
echo "================================================================================"
grep -nE "writeFileSync|mkdirSync|trace\.json|messages\.json|summary\.md|screenshots|latest" \
  skills/autobrowse/scripts/evaluate.mjs || true

echo
echo "================================================================================"
echo "[2] Simulate exact trace artifact writes with sensitive content"
echo "================================================================================"

mkdir -p "$WS/autobrowse/traces/demo/run-001/screenshots"

node <<NODE
const fs = require("fs");
const path = require("path");

const traceDir = "$WS/autobrowse/traces/demo/run-001";

const trace = {
  tool_log: "Full tool call log",
  request: {
    url: "https://example.com/private?token=SECRET_URL_TOKEN",
    headers: {
      Authorization: "Bearer SECRET_AUTH_TOKEN",
      Cookie: "session=SECRET_COOKIE"
    },
    postData: "username=admin&password=SECRET_PASSWORD"
  }
};

const messages = [
  {
    role: "user",
    content: "Login to private portal with password SECRET_PASSWORD"
  },
  {
    role: "assistant",
    content: "Used cookie session=SECRET_COOKIE and bearer token SECRET_AUTH_TOKEN"
  }
];

const summary = "# Summary\\nVisited private account page containing SECRET_ACCOUNT_DATA.\\n";

fs.writeFileSync(path.join(traceDir, "trace.json"), JSON.stringify(trace, null, 2));
fs.writeFileSync(path.join(traceDir, "messages.json"), JSON.stringify(messages, null, 2));
fs.writeFileSync(path.join(traceDir, "summary.md"), summary);
fs.writeFileSync(path.join(traceDir, "screenshots", "step-01.png"), "FAKE_SCREENSHOT_SECRET_VISIBLE");
NODE

ln -sfn "$WS/autobrowse/traces/demo/run-001" "$WS/autobrowse/traces/demo/latest"

echo
echo "================================================================================"
echo "[3] File and directory permissions"
echo "================================================================================"

echo "[+] Files:"
find "$WS/autobrowse/traces" -type f -exec stat -c "%a %A %U %G %n" {} \;

echo
echo "[+] Directories:"
find "$WS/autobrowse/traces" -type d -exec stat -c "%a %A %U %G %n" {} \;

echo
echo "[+] Symlink:"
ls -la "$WS/autobrowse/traces/demo/latest"

echo
echo "================================================================================"
echo "[4] Detect unsafe readable files and dirs"
echo "================================================================================"

BAD_FILES="$(find "$WS/autobrowse/traces" -type f -perm /077 -print || true)"
BAD_DIRS="$(find "$WS/autobrowse/traces" -type d -perm /077 -print || true)"

if [ -n "$BAD_FILES" ]; then
  echo "[CONFIRMED] Sensitive files are group/world readable:"
  echo "$BAD_FILES"
else
  echo "[OK] No group/world-readable files."
fi

if [ -n "$BAD_DIRS" ]; then
  echo "[CONFIRMED] Trace directories are group/world traversable/listable:"
  echo "$BAD_DIRS"
else
  echo "[OK] No group/world-accessible directories."
fi

echo
echo "================================================================================"
echo "[5] Secret extraction proof"
echo "================================================================================"

grep -RniE "SECRET_|password|Authorization|Bearer|Cookie|session=|token=" \
  "$WS/autobrowse/traces" || true

echo
echo "================================================================================"
echo "[6] Cross-user read simulation"
echo "================================================================================"

if id nobody >/dev/null 2>&1; then
  echo "[+] Trying read as nobody user..."
  set +e
  sudo -u nobody grep -RniE "SECRET_|password|Authorization|Bearer|Cookie|session=|token=" \
    "$WS/autobrowse/traces" 2>&1
  RC=$?
  set -e
  echo "[+] nobody read exit code: $RC"
  if [ "$RC" = "0" ]; then
    echo "[CONFIRMED] Another local user could read sensitive trace contents."
  else
    echo "[INFO] nobody could not read, likely because parent /tmp path blocks traversal."
    echo "[INFO] Still unsafe inside shared/workspace directories with permissive parent dirs."
  fi
else
  echo "[SKIP] nobody user not available."
fi

echo
echo "================================================================================"
echo "[7] Shared workspace simulation"
echo "================================================================================"

SHARED="$WORKDIR/shared_workspace"
mkdir -p "$SHARED"
chmod 755 "$SHARED"

cp -a "$WS/autobrowse" "$SHARED/"
chmod -R o+rx "$SHARED"

echo "[+] Shared workspace perms:"
find "$SHARED/autobrowse/traces" -maxdepth 4 -exec stat -c "%a %A %n" {} \;

if id nobody >/dev/null 2>&1; then
  echo "[+] Trying read from shared workspace as nobody..."
  set +e
  sudo -u nobody grep -RniE "SECRET_|password|Authorization|Bearer|Cookie|session=|token=" \
    "$SHARED/autobrowse/traces" 2>&1
  RC=$?
  set -e
  echo "[+] nobody shared-read exit code: $RC"
  if [ "$RC" = "0" ]; then
    echo "[CONFIRMED] In a shared-readable workspace, another local user can extract trace secrets."
  fi
fi

echo
echo "================================================================================"
echo "[8] Secure fix comparison"
echo "================================================================================"

SECURE="$WORKDIR/secure_workspace/autobrowse/traces/demo/run-001"
mkdir -p "$SECURE/screenshots"
chmod 700 "$WORKDIR/secure_workspace" "$WORKDIR/secure_workspace/autobrowse" "$WORKDIR/secure_workspace/autobrowse/traces" "$WORKDIR/secure_workspace/autobrowse/traces/demo" "$SECURE" "$SECURE/screenshots"

node <<NODE
const fs = require("fs");
const path = require("path");
const traceDir = "$SECURE";

fs.writeFileSync(path.join(traceDir, "trace.json"), JSON.stringify({secret: "SECRET_AUTH_TOKEN"}, null, 2), {mode: 0o600});
fs.writeFileSync(path.join(traceDir, "messages.json"), JSON.stringify([{secret: "SECRET_COOKIE"}], null, 2), {mode: 0o600});
fs.writeFileSync(path.join(traceDir, "summary.md"), "SECRET_SUMMARY", {mode: 0o600});
fs.writeFileSync(path.join(traceDir, "screenshots", "step-01.png"), "SECRET_SCREENSHOT", {mode: 0o600});
NODE

find "$WORKDIR/secure_workspace" -type f -exec stat -c "%a %A %n" {} \;
find "$WORKDIR/secure_workspace" -type d -exec stat -c "%a %A %n" {} \;

BAD_SECURE="$(find "$WORKDIR/secure_workspace" -type f -perm /077 -print || true)"
if [ -z "$BAD_SECURE" ]; then
  echo "[OK] Secure mode 0600 prevents group/world-readable trace files."
else
  echo "[FAIL] Secure test still has readable files:"
  echo "$BAD_SECURE"
fi

echo
echo "================================================================================"
echo "[9] Final verdict"
echo "================================================================================"

if [ -n "$BAD_FILES" ] || [ -n "$BAD_DIRS" ]; then
  echo "[CONFIRMED] Local information disclosure risk."
  echo
  echo "Issue:"
  echo "Trace artifacts containing raw API messages, tool logs, screenshots, URLs, headers, cookies, and tokens are written using default fs.writeFileSync permissions."
  echo
  echo "Impact:"
  echo "On systems with permissive umask or shared workspaces, other local users/processes may read sensitive traces."
  echo
  echo "Suggested fix:"
  echo "- Create trace directories with 0700"
  echo "- Write trace.json/messages.json/summary.md/screenshots with mode 0600"
  echo "- Consider redacting Authorization, Cookie, tokens, passwords before writing logs"
else
  echo "[NOT CONFIRMED] No unsafe perms in this environment."
fi

} | tee "$REPORT"

echo
echo "[+] Done."
echo "[+] Full report:"
echo "cat $REPORT"
