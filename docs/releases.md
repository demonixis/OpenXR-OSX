# Releases

## Scope

Use tagged release assets first when they cover your target platform. Build from source only when you need current branch changes, local instrumentation, or a platform variant that the release does not ship yet.

## Binary-First Paths

### macOS Runtime And Apps

If a release includes macOS runtime or app artifacts for the version you want to try, prefer those over a local source build:

- use the shipped runtime manifest and dynamic library together
- use the shipped app bundle for the macOS companion, simulator, or viewer when one is provided
- keep source builds for development, debugging, and unreleased fixes

You still need the normal macOS runtime registration step if you want GUI applications outside a shell session to see the runtime. See [build.md](build.md) for the runtime registration helper.

### Quest Android Client

If a release includes a Quest APK that matches the runtime/server version you want to test, sideload that APK before reaching for Gradle:

```bash
adb install path/to/openxr-osx-quest.apk
```

Use a source build when you need branch-only Android changes, custom instrumentation, or a local debug build.

## Release Automation

This repository uses Conventional Commits plus `release-please` to manage version bumps, `CHANGELOG.md`, and GitHub Releases.

The intended flow is:

1. merge pull requests with Conventional Commit subjects
2. let `release-please` open or update the release PR on `main`
3. merge the release PR to create the next semver tag
4. let the release workflow package and upload release assets from checked-in `scripts/ci/` entry points

Local release packaging reproduction stays script-first:

```bash
scripts/ci/package-release-assets.sh
```

That command assembles the runtime zip, Quest APK, macOS Companion app, Simulator app, and `SHA256SUMS.txt` under `dist/release/`.

## When To Build From Source

Use the source workflow in these cases:

- you are changing runtime, client, or protocol code
- you need the newest branch state instead of the latest tagged release
- you need local CTS, test, or sanitizer coverage
- you are validating a platform path that is not shipped as a release artifact yet

For source setup, continue with [install.md](install.md) and [build.md](build.md).
