# Path Traversal in Medusa Local File Provider (v2.15.5)

## Summary

A path traversal vulnerability exists in the Medusa Local File Provider (`@medusajs/file-local`) in version 2.15.5.

User-controlled filenames are incorporated into filesystem paths without validating that the resulting path remains within the configured upload directory. An attacker with file upload permissions may use directory traversal sequences (`../`) in a filename to cause files to be written outside the intended upload location.

## Affected Component

* Package: `@medusajs/file-local`
* Version: `2.15.5`
* File: `packages/modules/providers/file-local/src/services/local-file.ts`

## Technical Details

The local file provider parses user-supplied filenames using:

```ts
const parsedFilename = path.parse(file.filename)
```

The directory component of the supplied filename is preserved and later used when constructing the file key:

```ts
const fileKey = path.join(
  parsedFilename.dir,
  ...
)
```

The resulting path is subsequently used for file creation:

```ts
await fs.writeFile(filePath, content)
```

and

```ts
const writeStream = createWriteStream(filePath)
```

No validation is performed to ensure that the final resolved path remains within the configured upload directory.

As a result, filenames containing traversal sequences such as `../` may escape the intended upload location.

## Proof of Concept

The attached `poc.sh` script reproduces the issue.

Test filename:

```txt
../MEDUSA_CVE_POC.txt
```

Observed output:

```txt
[+] Upload dir: /tmp/medusa-local-provider-poc/uploads

Computed file_key:
../1780475568844-MEDUSA_CVE_POC.txt

Final path:
/tmp/medusa-local-provider-poc/1780475568844-MEDUSA_CVE_POC.txt

Escaped upload dir: True

[VULNERABLE] Path traversal file write outside upload directory confirmed.
```

Additional tests confirmed traversal outside the upload directory using:

```txt
../../MEDUSA_CVE_POC_2.txt
safe/../../MEDUSA_CVE_POC_3.txt
```

The proof of concept successfully created files outside the configured upload directory.

## Impact

An authenticated user with upload permissions may write files outside the intended upload directory when the local file provider is enabled.

The practical impact depends on deployment configuration and filesystem permissions available to the Medusa process. While direct remote code execution was not demonstrated, the vulnerability breaks expected filesystem isolation and allows creation of attacker-controlled files in unintended filesystem locations.

## Severity

Low

## CVSS v3.1

```txt
CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:N/I:L/A:N
```

Base Score: **2.7 (Low)**

## CWE

```txt
CWE-22: Improper Limitation of a Pathname to a Restricted Directory ('Path Traversal')
```

## Remediation

Validate the canonical path of the final file location before performing filesystem operations and ensure the resolved path remains within the configured upload directory.

Reject filenames containing traversal sequences or perform strict containment checks using resolved absolute paths prior to file creation.
