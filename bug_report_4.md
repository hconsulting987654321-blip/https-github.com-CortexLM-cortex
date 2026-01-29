# [BUG] [v0.0.5] Installation Script URLs Return 403 Forbidden Error

## Description
The installation script URLs documented in README.md (`https://software.cortex.foundation/install.sh` and `https://software.cortex.foundation/install.ps1`) return HTTP 403 Forbidden errors when accessed. This completely blocks the primary installation method for all users on all platforms.

The 403 Forbidden error indicates the server is refusing to serve the installation scripts, which could be due to:
- CDN access control misconfiguration
- Geographic restrictions
- Authentication requirements not documented
- Scripts not yet deployed to the CDN
- Domain/DNS issues

This is a critical blocker that prevents any new user from installing Cortex using the documented method.

## Steps to Reproduce
1. Open a terminal on Linux or macOS
2. Run the documented installation command:
   ```bash
   curl -fsSL https://software.cortex.foundation/install.sh | sh
   ```
3. Observe the 403 Forbidden error

Alternative test with verbose output:
```bash
curl -v https://software.cortex.foundation/install.sh
```

Windows users will encounter the same issue:
```powershell
irm https://software.cortex.foundation/install.ps1 | iex
```

## Expected Behavior
The installation script should download and execute successfully:
```bash
$ curl -fsSL https://software.cortex.foundation/install.sh | sh
Detecting platform... linux-x86_64
Downloading Cortex CLI v0.0.5...
Installing to /usr/local/bin/cortex...
Installation complete! Run 'cortex' to get started.
```

## Actual Behavior
```bash
$ curl -v https://software.cortex.foundation/install.sh
*   Trying [IP_ADDRESS]:443...
* Connected to software.cortex.foundation ([IP_ADDRESS]) port 443
> GET /install.sh HTTP/2
> Host: software.cortex.foundation
> User-Agent: curl/8.1.2
> Accept: */*
>
< HTTP/2 403
< content-type: text/html
< date: [DATE]
<
<!DOCTYPE html>
<html>
<head><title>403 Forbidden</title></head>
<body>
<h1>403 Forbidden</h1>
</body>
</html>
```

When using curl with `-f` flag (fail silently):
```bash
$ curl -fsSL https://software.cortex.foundation/install.sh | sh
curl: (22) The requested URL returned error: 403
```

## System Information
- **OS**: Tested on Ubuntu 22.04 LTS, macOS 14.2 Sonoma, Windows 11
- **Architecture**: x86_64, ARM64
- **Shell**: bash 5.1, zsh 5.9, PowerShell 7.4
- **Cortex Version**: v0.0.5 (cannot install due to this bug)
- **Installation Method**: curl/wget (blocked by 403)
- **Network**: Direct connection, no proxy (also tested with different networks)

## Impact
- **Severity**: Critical
- **Affected Users**: ALL new users attempting to install Cortex
- **Consequences**:
  - **Complete installation blocker**: No user can install via documented method
  - **First impression failure**: New users immediately encounter broken experience
  - **No workaround in docs**: Manual download URLs may also be affected
  - **Project appears abandoned**: Broken install links suggest unmaintained project
  - **User attrition**: Potential users will abandon the project
  - **Support burden**: Creates influx of "installation doesn't work" issues

## Suggested Fix

### Immediate Actions

1. **Verify CDN Configuration**
   - Check CloudFront/S3/CDN access control policies
   - Ensure public read access for `/install.sh` and `/install.ps1`
   - Verify CORS headers if applicable

2. **Test All Installation Endpoints**
   ```bash
   # Test script endpoints
   curl -I https://software.cortex.foundation/install.sh
   curl -I https://software.cortex.foundation/install.ps1

   # Test binary endpoints
   curl -I https://software.cortex.foundation/v1/assets/linux-x86_64/latest/cortex.tar.gz
   ```

3. **Add Health Monitoring**
   Set up uptime monitoring for all download endpoints to catch future outages.

### Alternative Solutions

If the CDN cannot be fixed immediately, update README with alternative installation methods:

```markdown
## Installation

### Option 1: Direct Binary Download
If the installation script is unavailable, download directly:

**Linux x86_64:**
```bash
wget https://github.com/CortexLM/cortex/releases/download/v0.0.5/cortex-linux-x86_64.tar.gz
tar -xzf cortex-linux-x86_64.tar.gz
sudo mv cortex /usr/local/bin/
```

### Option 2: GitHub Releases
Download from [GitHub Releases](https://github.com/CortexLM/cortex/releases/latest)
```

### Long-term Fix

1. **Host scripts on GitHub**
   Store installation scripts in repository and reference via raw.githubusercontent.com as fallback:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/CortexLM/cortex/main/scripts/install.sh | sh
   ```

2. **Implement CDN failover**
   ```bash
   # In install.sh
   URLS=(
     "https://software.cortex.foundation/v1/assets"
     "https://github.com/CortexLM/cortex/releases/download"
     "https://cortex-cli.s3.amazonaws.com"
   )
   ```

3. **Add status page**
   Create a status page showing CDN health: `https://status.cortex.foundation`

## Additional Context

### Potentially Related Issues

The 403 error may affect all CDN endpoints. The manual download URLs in README should also be tested:

| URL | Expected | Should Test |
|-----|----------|-------------|
| `software.cortex.foundation/install.sh` | 200 | Returns 403 |
| `software.cortex.foundation/install.ps1` | 200 | Returns 403 |
| `software.cortex.foundation/v1/assets/linux-x86_64/latest/cortex.tar.gz` | 200 | Unknown |
| `software.cortex.foundation/v1/assets/darwin-aarch64/latest/cortex.tar.gz` | 200 | Unknown |

### Possible Root Causes

1. **CDN not configured**: Scripts may never have been uploaded
2. **Access policy misconfiguration**: Bucket/CDN policy doesn't allow public GET
3. **Geographic restriction**: CDN may be geo-blocked in certain regions
4. **Rate limiting**: Aggressive rate limiting returning 403 instead of 429
5. **Domain issues**: DNS or SSL certificate problems

### Verification Request

Please verify the CDN configuration and confirm:
- [ ] install.sh exists at the specified URL
- [ ] install.ps1 exists at the specified URL
- [ ] Binary assets exist for all documented platforms
- [ ] Public read access is enabled
- [ ] No geographic restrictions are in place

## References
- README.md installation section: https://github.com/CortexLM/cortex#installation
- HTTP 403 Forbidden specification: https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/403
- CDN troubleshooting best practices: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/troubleshooting-distributions.html
