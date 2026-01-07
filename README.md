# Romifleur

![Romifleur Logo](assets/logo-romifleur.png)

![Romifleur Screenshot](assets/Romifleur_screen.png)

---

## 🇺🇸 English

### What is Romifleur?
**Romifleur** is a modern, user-friendly desktop application designed to simplify the process of finding and downloading retro game ROMs. Built with Python and CustomTkinter, it provides a sleek interface to browse extensive catalogs for various classic consoles, offering a streamlined alternative to navigating complex archive websites manually.

### Features
*   **Modern GUI**: A clean, dark-themed interface powered by CustomTkinter.
*   **Multi-Console Support**: Access libraries for NES, SNES, N64, GameCube, PS1, PSP, Sega Genesis, Dreamcast, and more.
*   **Rich Metadata Integration**: Thanks to [**TheGamesDB**](https://thegamesdb.net/), view game thumbnails, descriptions, release dates, and more directly in the app.
*   **Smart Search & Filtering**:
    *   Real-time search bar.
    *   **Region Filters**: Easily toggle between Europe, USA, and Japan versions.
    *   **Clean List**: Option to hide Demos, Betas, and Prototypes automatically.
*   **Enhanced Download Queue**: 
    *   Add multiple games from different consoles to a persistent queue.
    *   **Size Calculation**: Automatically calculates the total size of your download queue.
    *   **Batch Downloading**: Download your entire queue in parallel with a single click.
*   **Custom Download Path**: Choose exactly where your ROMs go (e.g., directly to an SD card). The app automatically creates standard console folders.
*   **Deduplication**: Automatically identifies and prioritizes the best version of a game (e.g., latest revision, preferred region).
*   **Cross-Platform Builds**: Now available for **Windows**, **macOS**, and **Linux**! 
*   **RetroAchievements Support**: API integration to see which games have achievements, now with custom AI-generated PNG icons for consistent rendering across OS.

### How to Use
1.  **Launch the App**: Open `Romifleur.exe` (or run `main.py`).
2.  **Select a Console**: Choose a platform from the left sidebar.
3.  **Find Games**: Use the search bar or scroll through the list.
4.  **Select Games**: Click the checkbox `[ ]` next to games or use the "Select All" button.
5.  **Queue**: Click **"Add to Queue ➡️"** to send them to the download panel on the right.
6.  **Download**: Click **"Start Downloads 🚀"** in the right panel to begin.
6.  **Download**: Click **"Start Downloads 🚀"** in the right panel to begin.
7.  **(Optional)** Click **"Settings ⚙️"** to change the download destination folder.
8.  **(Optional - RetroAchievements)** In **Settings**, enter your **Web API Key** (found in your [RetroAchievements Control Panel](https://retroachievements.org/controlpanel.php)) to enable compatibility badges (🏆).
9.  **Play**: Click "Open ROMs Folder" to access your downloaded files, automatically organized by console.

### For Developers (v2.0.0 Refactor)
The codebase has been completely refactored into a cleaner, MVC-like architecture. Logic and UI are deeply separated, components are modular (`src/core`, `src/ui`, `src/utils`), and app scaling is improving across all resolutions.

### Development & Compilation
**Requirements:**
*   Python 3.9+
*   `pip install customtkinter requests beautifulsoup4 pillow pyinstaller py7zr`

**Running from Source:**
```bash
python main.py
```

To build a standalone executable that includes all assets (icons, database), **open a terminal in the project's root directory** and run:

**Compiling to Executable (.exe):**
```bash
pyinstaller --noconsole --onefile --icon=icon.ico --name Romifleur --add-data "consoles.json;." --add-data "logo-romifleur.png;." --add-data "logo-romifleur-mini.png;." --collect-all customtkinter main.py
```
The output file will be located in the `dist/` folder.

**Compiling for MacOS (ARM):**
Use `:` as separator and `--onedir` might be preferred for some setups, but `--onefile` usually works too.
```bash
pyinstaller --noconsole --onedir --icon=icon.ico --name Romifleur --add-data "consoles.json:." --add-data "logo-romifleur.png:." --add-data "logo-romifleur-mini.png:." --collect-all customtkinter main.py
```
The output file will be located in the `dist/` folder.

**Compiling for Linux:**
Use `:` as separator.
```bash
pyinstaller --noconsole --onefile --name Romifleur --add-data "consoles.json:." --add-data "logo-romifleur.png:." --add-data "logo-romifleur-mini.png:." --collect-all customtkinter main.py
```

**Running on Linux:**
For the standalone binary (from Releases or built):
```bash
chmod +x Romifleur
./Romifleur
```

---

## Acknowledgements / Remerciements
*   Thanks to **@mikeflystar** for providing the MacOS (ARM) compilation instructions.