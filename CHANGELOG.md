# Changelog

All notable changes to this project will be documented in this file.

## [3.0.7] - 2026-02-01
### Fixed
- **Android**: Fixed `PathAccessException` on Android 11+ (Galaxy Fold, Pixel, etc.) by properly requesting Storage Permissions (`MANAGE_EXTERNAL_STORAGE`).
- **Android**: Added `permission_handler` to manage runtime permissions for downloads.

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
