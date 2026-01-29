# [BUG] [v0.1.0] No GitHub User Existence Verification During Registration

## Description

The registration wizard accepts any GitHub username without verifying that the user actually exists on GitHub. This allows miners to register with non-existent or typo'd usernames, which means:

1. They can never receive rewards (issues are linked by GitHub username)
2. They won't discover the mistake until much later
3. Invalid registrations pollute the database

The GitHub API client exists in the codebase but is not used during registration to validate usernames.

## Steps to Reproduce

1. Run the registration wizard:
```bash
bounty wizard
```

2. Enter your miner secret key (any valid key)

3. When prompted for GitHub username, enter a non-existent username:
```
GitHub username: this_user_definitely_does_not_exist_12345
```

4. The registration succeeds without any warning

5. Later, when creating issues, rewards cannot be attributed because the username doesn't match any real GitHub user

## Expected Behavior

The wizard should verify the GitHub username exists before completing registration:

```
GitHub username: this_user_definitely_does_not_exist_12345
  Verifying GitHub user...
  Error: GitHub user 'this_user_definitely_does_not_exist_12345' not found.
  Please enter a valid GitHub username.
```

## Actual Behavior

The wizard only performs local format validation (alphanumeric, hyphens, max 39 chars) but doesn't verify the user exists on GitHub:

```
GitHub username: this_user_definitely_does_not_exist_12345
  ✓ GitHub: @this_user_definitely_does_not_exist_12345

  Review Registration
  ────────────────────────────────────────
  Hotkey:   5GrwvaEF5z...
  GitHub:   @this_user_definitely_does_not_exist_12345

  Register this GitHub account? [Y/n] y
  ✓ Registration successful!
```

The registration completes despite the username being invalid.

## System Information

- **OS**: Ubuntu 22.04 LTS
- **Architecture**: x86_64
- **Rust Version**: rustc 1.75.0
- **Bounty CLI Version**: v0.1.0

## Impact

- **Severity**: Medium
- Users who make typos in their username lose all potential rewards
- No way to recover - must re-register with correct username
- Wasted effort creating issues that won't be credited
- Database pollution with invalid registrations
- Poor user experience when users discover the issue later

## Suggested Fix

Add GitHub user verification before registration in `src/bin/bounty/wizard/register_wizard.rs`:

```rust
use reqwest::Client;

async fn verify_github_user(username: &str) -> Result<bool> {
    let client = Client::new();
    let url = format!("https://api.github.com/users/{}", username);

    let response = client
        .get(&url)
        .header("User-Agent", "bounty-challenge/0.1.0")
        .header("Accept", "application/vnd.github+json")
        .send()
        .await?;

    Ok(response.status().is_success())
}

// In run_register_wizard(), after username input:
println!("  Verifying GitHub user...");
if !verify_github_user(&github_username).await? {
    anyhow::bail!(
        "GitHub user '{}' not found. Please check the spelling and try again.",
        github_username
    );
}
```

**Alternative server-side fix:**

The server could also validate the username exists before accepting registration in `src/server.rs`:

```rust
async fn register_handler(...) -> Json<RegisterResponse> {
    // ... existing validation ...

    // Verify GitHub user exists
    let github_client = crate::github::GitHubClient::new("", "");
    let url = format!("https://api.github.com/users/{}", request.github_username);
    // ... check response ...
}
```

## References

- `src/bin/bounty/wizard/register_wizard.rs:57-77` - Local validation only
- `src/github.rs` - GitHub API client (exists but not used for user verification)
- `src/server.rs:226-313` - Registration handler (no user existence check)
