# Changelog

All notable changes to this project will be documented in this file.

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
