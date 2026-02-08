# Changelog

All notable changes to this project will be documented in this file.

## [3.3.8] - 2026-02-08
### Fixes 🐛
- **Windows False Location Usage**: Fixed Windows showing "your location is being used" in the taskbar permanently. Caused by `permission_handler_windows` plugin registering a WinRT Geolocator listener at startup even though the app never uses location. Replaced with a no-op override since permissions are only needed on Android. ([#1289](https://github.com/Baseflow/flutter-permission-handler/issues/1289))

## [3.3.7] - 2026-02-07
### Fixes 🐛
- **Silent Download Truncation**: Fixed critical bug where HTTP streams closing silently (network drop, server reset) produced incomplete files saved as complete. Added content-length verification after every download stream loop (3 locations: regular path, SAF ZIP, SAF non-ZIP).
- **No HTTP Timeout**: Downloads used a bare `http.Client()` with no timeout configuration. Replaced with `IOClient` wrapping `HttpClient` with `connectionTimeout: 30s` and `idleTimeout: 60s` — stalled connections are now detected and errored.
- **Retry with Resume**: Failed downloads now automatically retry up to 3 times with HTTP Range resume. Incomplete `.tmp` files are preserved between retries. If the server doesn't support Range (responds 200 instead of 206), the download restarts from 0.
- **Server Download Verification (Docker/Web)**: Server-side downloads now use manual stream processing with content-length verification instead of blind `.pipe()`. Added IOClient with 120s idle timeout.

## [3.3.6] - 2026-02-06
### Fixes 🐛
- **Out of Memory on Large ROMs (Android)**: Fixed OOM crash when extracting large ZIP files (PSP 1.5GB+) on Android. Switched from `ZipDecoder().decodeBuffer()` (loads entire ZIP into RAM) to `extractFileToDisk()` (streams file-by-file from disk). Same fix as server-side v3.3.1, now applied to native Android.
- **Docker/Web Build**: Fixed web compilation errors caused by missing `DownloadProgressEvent` class and `subtext` parameter in web stubs.

## [3.3.5] - 2026-02-06
### Fixes 🐛
- **Android Download Crash**: Fixed downloads stopping at ~70% with 0GB files on SAF devices (Odin 2, phones) — `writeFuture` was not awaited on error path.
- **Extraction Freeze**: Fixed progress bar stuck during ZIP extraction — `processedBytes` was not incremented in the `List<int>` branch.
- **Isolate Crash Detection**: Added exit listeners to detect isolate OOM crashes on large files (PS2) instead of hanging forever.
- **Silent Extraction Failures**: Extraction errors are now properly propagated instead of being silently swallowed.
- **PS2 File Corruption (Issue #38)**: Added post-extraction file size verification to detect corrupted extractions.
- **Disk Full Error (Issue #43)**: Pre-download disk space check with clear error message. Catches OS-specific disk full errors (ENOSPC, ERROR_DISK_FULL).
- **Memory Leak**: Fixed `StreamSubscription` leak in MetadataService when closing details dialog during loading.
- **Cache Corruption**: Debounced cache saves (500ms) to prevent concurrent file writes.

### Performance ⚡
- **Search Debounce**: 300ms debounce on search input — reduces rebuilds from every keystroke to ~3/s.
- **Cached Ownership Scan**: Filesystem scan results are now cached and only refreshed on console change or after download.
- **LRU ROM Cache**: ROM lists limited to 10 entries with 30min TTL to prevent unbounded memory growth.
- **Image Caching**: Cover images now use `CachedNetworkImage` instead of re-downloading on each dialog open.
- **ListView Performance**: Added `itemExtent` for smoother scrolling on large lists (5000+ ROMs).
- **Reduced Rebuilds**: Merged double state updates in search — 1 rebuild instead of 2-3.

### Code Quality 🧹
- **Structured Logging**: Replaced all `print()` calls with `AppLogger` (debug/info/warning/error levels, suppressed in release mode).
- **Specific Error Handling**: `FileSystemException` caught specifically for disk-full scenarios with OS error codes.
- **Magic Strings**: Extracted SharedPreferences keys to constants.

## [3.3.4] - 2026-02-05
### New Features 🚀
- **Background Downloads**: Downloads now continue reliably when the app is in the background or screen is off (Android).
- **Progress Notifications**: A notification now shows the progress of the active download.
- **About Dialog**: Added an info screen in Settings with version and credits.

### Fixes 🐛
- **Windows Support**: Fixed a crash when starting downloads on Windows caused by Android-specific background services.
- **Android Game Detection**: Fixed an issue where downloaded games were not recognized (SAF subfolder scanning).
- **Build**: Fixed build errors related to Android core library desugaring.

## [3.3.3] - 2026-02-05
### Fixed
- **Android SD Card Support (Issue #46)**: Implemented full support for downloading to external SD cards on Android 11+ using the Storage Access Framework (SAF).
  - Fixed `PathAccessException` / "Invalid URI" errors when writing to external storage.
  - Implemented robust ZIP extraction for SAF: Downloads to temp cache -> Extracts -> Copies to SD Card.
  - Added native folder picker for compliant access to SD cards.
  - Improved progress bar accuracy to reflect download, extraction, and copy steps.

## [3.3.2] - 2026-02-04
### Fixed
- Code cleanup: removed unused imports and fixed lint warnings.

## [3.3.1] - 2026-02-04
### Fixed
- **Out of Memory on Large ROMs (Issue #45)**: Fixed extraction crash on files 600MB+ by switching to streaming extraction (`extractFileToDisk`). Affects both Native and Docker/Web versions.

## [3.3.0] - 2026-02-04
### Added
- **Custom Console Folders** (Issue #11): Assign unique download folders per console.
  - Native: Browse button to select any folder on your system.
  - Web/Docker: Dropdown to select or create folders in the mounted volume.
  - Settings > Console Folders section with expandable list.
- **ROM Ownership Scanning** (Issue #11): Automatically detects ROMs you already own.
  - 🟢 Green border + checkmark = Exact match (same filename).
  - 🔵 Blue border + checkmark = Partial match (same game, different version).
  - Tooltips on hover explain each status.
- **Auto-Refresh**: ROM list updates in real-time after downloads complete (Native).
- **Server APIs**: New endpoints for folder management and ROM scanning (Docker).
- **Download Cancellation**: 
  - Stop ongoing downloads with the Cancel button (❌).
  - Automatically cleans up partial files (.tmp).
  - Preserves pending queue items while cancelling the current one.
- **Ownership Filters**: 
  - Hide games you already own (Hide Owned 🟢).
  - Hide similar versions/partial matches (Hide Similar 🔵).


## [3.2.3] - 2026-02-03
### Added
- **Update Checker**: Automatically notifies users when a new version of Romifleur is available.
- **Changelog**: Displays the list of changes (Changelog) directly in the application during an update.
- **Web/Docker**: The "View Release" button redirects to the GitHub release page for manual updating (docker pull).

## [3.2.2] - 2026-02-03
### Added
- **New Consoles Supported**: Massive update to the console list!
  - **Nintendo**: Wii, Wii U, Virtual Boy
  - **Sega**: Sega 32X, Sega CD, SG-1000
  - **Sony**: PS3
  - **Microsoft**: Xbox, Xbox 360
  - **NEC**: PC Engine CD, SuperGrafx
  - **SNK**: Neo Geo Pocket, Neo Geo Pocket Color
  - **Atari**: 5200, 7800, Lynx, Jaguar, Jaguar CD

### Changed
- **Metadata**: Updated all Platform IDs for TheGamesDB and IGDB to support the new consoles.

### Removed
- **Unsupported Systems**: Removed experimental/unsupported systems to focus on core consoles:
  - Bandai (WonderSwan)
  - 3DO
  - Philips CD-i
  - Arcade (MAME, FBNeo)

## [3.2.1] - 2026-02-03
### Added
- **Multi-Source Metadata**: Added system to query multiple APIs (TheGamesDB + IGDB) in parallel.
- **Progressive Enrichment**: Data loads instantly from the fastest source and automatically fills in missing details as others respond.
- **Extended Game Details**:
  - 🏠 Developer & Publisher
  - 🎭 Genre
  - ⭐ Rating
  - 📅 Release Year
  - 🎮 Player Count (when available)
- **Visual Improvements**: New grid layout for game details and styled metadata badges.

## [3.2.0] - 2026-02-03
### Added
- **Language Filters**: Filter ROMs by language (En, Fr, De, Es, It, Ja). Combine with region filters!
- **World Region**: Added "World" region filter for `(World)` releases.
- **Hide Unlicensed**: New filter to hide `(Unl)` unlicensed/pirate ROMs.

### Changed
- **Show All Versions**: Removed auto-deduplication that hid USA/Japan versions. All matching versions now displayed.
- **Filter Badge Removed**: Removed the incomplete filter count badge from filter button.

### Fixed
- **USA Games Missing** (#37): Fixed bug where USA versions were hidden due to region scoring bias.
- **Landscape Mode (Android)**: Fixed UI being hidden by notch/navigation bar in landscape orientation.
- **Desktop Divider**: Fixed missing vertical divider between ROM list and Download Queue on Windows/Linux/macOS.

## [3.1.3] - 2026-02-02
### Fixed
- **Linux AppImage**: Fixed critical issues preventing launch on Arch Linux/Wayland (KDE Plasma, GNOME 40+).
  - **"No GL implementation"**: Excluded system-specific graphics libraries (`libGL`, `libGLX`, `libEGL`, `libwayland-*`, `libdrm`, `libgbm`) to use host drivers.
  - **"Invalid ELF path" (AOT)**: Implemented wrapper script to set `LD_LIBRARY_PATH` and working directory, ensuring `libapp.so` is found at runtime.
  - Restructured AppDir to preserve Flutter bundle integrity (`/usr/share/romifleur/`).

## [3.1.2] - 2026-02-02
### Added
- **Docker**: Added multi-platform support (AMD64 & ARM64). Now runs on Raspberry Pi and other ARM devices! 🥧

## [3.1.1] - 2026-02-02
### Fixed
- **Docker**: Fixed issue where downloaded zip archives were not deleted after extraction in the Web version.
- **Linux**: Fixed AppImage generation issues (icon resolution, dependency copying, and internal renaming).

## [3.1.0] - 2026-02-01
### Added
- **UI**: Added Total Download Size calculator in the "Start Downloads" button (e.g., "3.7 GB - Start Downloads").
- **Linux**: Added AppImage support (`.AppImage`) for easier distribution.
- **Distribution**: Structured release archives (Windows, Linux, MacOS) with a cleaner `Romifleur/` root folder.

### Fixed
- **Android**: Fixed `PathAccessException` on Android 11+ by implementing runtime storage permissions (`MANAGE_EXTERNAL_STORAGE`).
- **Android**: Added `permission_handler` to manage runtime permissions.

## [3.0.6] - 2026-02-01
### Fixed
- **Android UI**: Resolved filter screen overflow issues on smaller devices.
- **Android UI**: Fixed unresponsive country selection toggles causing "Bad state" errors.
- **Landscape Layout**: Prevented header cut-off by respecting system Safe Areas (Notch/Nav Bar).
- **Settings Dialog**: Fixed layout overflow in landscape mode by making the dialog scrollable.
- **Desktop Layout**: Fixed inconsistent layout transitions when resizing windows (Removed dead zone between 600px-913px).

### Changed
- **UX/UI**: Replaced the fixed bottom "Add to Queue" bar with a **Floating Action Button (FAB)** for better space efficiency.
- **UX/UI**: Optimized "Compact" layout to be the default for Landscape and Tablet Portrait (< 960px).
- **Header**: Added dynamic game count to search bar hint (e.g., "Search in 496 games...").
- **Header**: Added a specialized menu for "Select All" / "Deselect All" actions.

## [3.0.5] - 2026-01-31
### Fixed
- **Docker**: Documentation updates and fix for image visibility settings.
- **Windows**: Fixed "DLL Missing" error by ensuring dependencies are correctly packaged in the zip release.

## [3.0.4] - 2026-01-30
### Fixed
- **Android**: Added `INTERNET` permission to `AndroidManifest.xml` to fix "No Games Found" error.

## [3.0.0] - 2026-01-28
### Added
- **New Architecture**: Complete rewrite moving from Python to **Flutter**.
- **Web Support**: Added Dockerized web version (`rom-service-web`) with server-side download handling.
- **Design**: Brand new "Romifleur" logo and updated icons.
- **Features**:
  - RetroAchievements integration with filters (Hardcore/Softcore/Unlocks).
  - Region filtering (USA/Europe/Japan) with instant toggles.
  - "Add to Queue" system with visual feedback.
  - Sidebar navigation for Consoles.
