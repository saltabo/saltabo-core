# Saltabo

Production-style macOS utility that replaces default app switching with a Space-aware switcher and adds Dock hover previews using AppKit.

## Setup

1. Open `Saltabo.xcodeproj` in Xcode.
2. Run the `Saltabo` target.
3. On first launch, grant:
   - `Accessibility`
   - `Input Monitoring`
4. Quit and reopen the app after granting permissions.

## Permissions and Runtime Requirements

- `Accessibility` is required for raising exact windows, inspecting Dock accessibility elements, and reading deeper metadata.
- `Input Monitoring` is required for a HID-level `Command + Tab` override.
- `App Sandbox` should remain disabled for this utility-style app.

## Main Components

- `AppSwitcherManager`: intercepts `Command + Tab`, limits results to the active Space, and commits selection on key release.
- `SpaceAwareWindowService`: reads CGWindow metadata, groups windows by app, and focuses exact windows.
- `DockPreviewManager`: watches global mouse movement and uses Accessibility hit-testing against Dock elements.
- `ThumbnailCache`: caches `CGWindow` thumbnails for previews.
- `AccessibilityService`: permission checks, AX traversal, exact window focus, and Dock hit-testing helpers.
- `FloatingSwitcherWindow`: centered Windows-style switcher for the active Space.
- `PreviewPanelWindow`: thumbnail preview panel shown above the Dock.

## Public API Limitations

- macOS does not expose a first-class public API for Dock hover events. This app uses Accessibility hit-testing as the closest practical approach.
- Exact browser-tab previews are not guaranteed through public APIs. The app falls back to window titles and AX metadata where available.
- Overriding the system `Command + Tab` is sensitive to TCC permissions and may still be affected by OS-level behavior after updates.

## Fallback Strategies

- If Dock hit-testing cannot map the hovered icon to a running app, the preview panel stays hidden instead of guessing.
- If exact AX window raise fails, the app falls back to activating the owning application.
- If `Command + Tab` interception is blocked by permissions, the app requests permissions and explains the missing access.

## App Updates (Appcast + Check for Updates)

The menu includes **Check for Updates...**. It reads `SUFeedURL` from `Info.plist`,
fetches an appcast XML, and compares versions.

**Layout (GitHub Pages + GitHub Releases):**

- **GitHub Pages** hosts only `appcast.xml` (static feed URL, HTTPS, easy to cache).
- **GitHub Releases** hosts the update archive (e.g. `Saltabo.zip`). The appcast’s `<enclosure url="…">` points at the release asset URL.

### 1) Configure `SUFeedURL`

In `Info.plist`, set:

- **User/org site** (repo named `<username>.github.io`, e.g. `saltabo/saltabo.github.io`):  
  `SUFeedURL` = `https://<username>.github.io/appcast.xml`
- **Project site** (Pages from a normal repo):  
  `SUFeedURL` = `https://<username>.github.io/<repo>/appcast.xml`

This app’s workflow (below) pushes `appcast.xml` to `<owner>/<owner>.github.io`, so for org `saltabo` use:

- `https://saltabo.github.io/appcast.xml`

### 2) Enable GitHub Pages

1. Repo **Settings → Pages**: choose **Deploy from a branch** (e.g. `gh-pages` / root) or **GitHub Actions** if you prefer.
2. After the first deploy, confirm `appcast.xml` opens in the browser at the `SUFeedURL` you set above.

### 3) Create a signed update archive (GitHub Release)

1. Archive the app with symlinks preserved (Sparkle [recommends](https://sparkle-project.org/documentation/publishing/) `ditto`):

   ```bash
   ditto -c -k --sequesterRsrc --keepParent "build/Build/Products/Release/Saltabo.app" "Saltabo.zip"
   ```

2. Create a **GitHub Release** (tag e.g. `v1.0.1`) and attach `Saltabo.zip` as a release asset. The public download URL will look like:

   `https://github.com/<owner>/<repo>/releases/download/<tag>/Saltabo.zip`

### 4) Generate `appcast.xml` with Sparkle’s `generate_appcast`

Do **not** hand-edit signatures. Use the tool from a [Sparkle release](https://github.com/sparkle-project/Sparkle/releases) (`Sparkle-*/bin/generate_appcast`) or from a Sparkle build.

1. One-time: create signing keys with Sparkle’s `generate_keys` (see Sparkle docs). Keep the **private** key secret; the **public** key is embedded in the app when you integrate `Sparkle.framework` (this repo currently uses a lightweight XML parser only—signatures are still good practice for a real Sparkle-based updater later).

2. Point `generate_appcast` at a folder that contains your zip and pass the **GitHub Releases** URL prefix so `<enclosure url>` matches the asset URL:

   ```bash
   export SPARKLE_BIN="/path/to/Sparkle/bin/generate_appcast"
   export GITHUB_OWNER="yourname"
   export GITHUB_REPO="Saltabo"
   export RELEASE_TAG="v1.0.1"
   export SPARKLE_EDDSA_KEY_FILE="/path/to/your/private-key-file"   # optional but recommended

   ./scripts/generate-appcast.sh /path/to/Saltabo.zip -o appcast.xml
   ```

3. Commit `appcast.xml` to the branch/folder that GitHub Pages serves (e.g. push to `gh-pages`).

The template `appcast.xml` at the repo root is an example; production feeds should be **generated** so `sparkle:edSignature` and `length` stay correct.

More detail: [Publishing an update](https://sparkle-project.org/documentation/publishing/) (Sparkle).

### GitHub Actions (publish to `saltabo.github.io`)

Workflow: [`.github/workflows/publish-pages.yml`](.github/workflows/publish-pages.yml). It runs when you **push a tag** matching `v*`:

1. Builds `Saltabo.app` (Release), zips with `ditto`, creates/updates release `vX.Y.Z` on `saltabo/saltabo.github.io`, uploads **`Saltabo.zip`** there.
2. Downloads Sparkle, runs `scripts/generate-appcast.sh` so `<enclosure url>` matches  
   `https://github.com/<owner>/<owner>.github.io/releases/download/<tag>/Saltabo.zip`.
3. Commits **`appcast.xml`** to the Pages repository (by default `<github-owner>/<github-owner>.github.io`, e.g. `saltabo/saltabo.github.io`) on that repo’s default branch.

**Secrets** (repo → *Settings → Secrets and variables → Actions*):

| Secret | Purpose |
|--------|---------|
| `SPARKLE_EDDSA_PRIVATE_KEY` | Full contents of the private key file from Sparkle’s `generate_keys` (same key you use locally). |
| `PAGES_DEPLOY_TOKEN` | Fine-grained PAT: **Contents: Read and write** on the `saltabo.github.io` repo (and read access to metadata). |

If the Pages repo name is not `<owner>/<owner>.github.io`, edit `PAGES_REPOSITORY` in the workflow file.

**Pages repo:** enable **GitHub Pages** on the default branch (root or `/docs`). After the first workflow run, open `https://saltabo.github.io/appcast.xml` and set that URL as `SUFeedURL` in `Info.plist`.
