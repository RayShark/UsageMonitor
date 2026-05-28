# Releasing 用量监控

Releases are handled by the GitHub Actions release workflow.

Current releases package the API-key usage monitor flow: users configure Base URL and API Key only, and the app refreshes `GET /v1/usage`.

## Branch Release

```bash
git checkout main
git pull origin main
git checkout -b release/v2.0.0
git push -u origin release/v2.0.0
```

The workflow validates the version, stamps `Resources/Info.plist`, runs tmux plugin shell tests and Swift tests, builds `UsageMonitor.app`, creates `UsageMonitor.dmg`, publishes a GitHub Release, and opens a merge-back PR.

Version tags with a prerelease suffix such as `v2.1.0-beta.1` are published as GitHub prereleases automatically. Manual dispatch can still override the prerelease flag when needed.

## Manual Dispatch

Use **Actions > Release > Run workflow**, enter a semver version, and choose draft or prerelease flags if needed.

## Published Files

- `UsageMonitor.dmg`
- `UsageMonitor.dmg.sha256`
- `usage-monitor-linux-amd64.tar.gz`
- `usage-monitor-linux-amd64.tar.gz.sha256`

## Local Verification

```bash
swift test
swift build
./scripts/build-app.sh
./scripts/create-dmg.sh
./scripts/build-linux-cli.sh
for test in tmux/tests/*_test.sh; do bash "$test"; done
```
