# Security Policy

Linggan Floating Ball handles clipboard content, screenshots, OCR text, and optional AI requests. Please treat privacy and local data handling as security-sensitive.

## Supported Versions

The project is pre-1.0. Security fixes target the `main` branch until tagged releases exist.

## Reporting a Vulnerability

Do not include private clipboard content, API keys, encrypted local state, or screenshots with sensitive information in public issues.

For now, please open a GitHub issue with a minimal description of the behavior and mark it clearly as security-sensitive without including secrets. As the project matures, a private security advisory flow will be added.

Good report shape:

- Affected feature, such as clipboard monitoring, persistence, AI tagging, or paste automation.
- What data could be exposed or modified.
- Steps to reproduce using dummy content.
- macOS version and app commit or release.

## Security Expectations

Contributions should preserve these boundaries:

- No telemetry.
- No cloud sync by default.
- No upload of clipboard content unless the user explicitly enables AI tagging.
- API keys stay in macOS Keychain.
- Local snippets stay encrypted at rest.
- Build artifacts and local app data stay out of git.

## Secret Scanning

Run the local project check before pushing or tagging a release:

```bash
./Scripts/check-project.sh
```

This includes `./Scripts/check-secrets.sh`, which scans git-tracked files for common token shapes such as GitHub personal access tokens, OpenAI-compatible `sk-` keys, Slack tokens, and AWS access keys.

If a real token was pasted into the repository or a public issue, remove it from the content, rotate or revoke it with the provider, and avoid reusing that token. The scanner is a guardrail, not a replacement for careful review of screenshots, logs, release notes, and issue text.

## Known Limitations

- Local builds are not currently signed or notarized.
- Accessibility permission is required for simulated paste behavior.
- Optional AI tagging sends snippet text to the configured provider.
