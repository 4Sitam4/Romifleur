# Romifleur Linux Compatibility Fixes

This document covers fixes implemented to resolve crashes and compatibility issues when running Romifleur on certain Linux configurations (ie, RHEL 9).

## The Problem

On some Linux systems—particularly those running X11 with Intel integrated graphics (Alder Lake, Raptor Lake)—the application would crash immediately on startup with errors like:

```
Error loading logos: PIL.Image and PIL.ImageTk couldn't be imported
```

```
X Error of failed request:  BadLength (poly request too large or internal Xlib length error)
  Major opcode of failed request:  139 (RENDER)
  Minor opcode of failed request:  20 (RenderAddGlyphs)
```

## Root Causes

### 1. Missing PIL/Tk Bindings

On RHEL, Fedora, and similar distributions, the `pillow` Python package doesn't include Tk bindings by default. These are provided by a separate system package (`python3-pillow-tk`), which wasn't installed.

### 2. X11 Emoji Rendering Bug

The second error is a known X.org bug that occurs when rendering certain Unicode characters—specifically emoji and special symbols like ⚙️, 🚀, ☐, ☑, ▼, etc. The X server's RENDER extension fails when trying to create glyphs for these characters, crashing the application.

This issue is most common on:
- X11 (not Wayland)
- Intel Alder Lake or Raptor Lake integrated graphics
- Systems without proper emoji font support

## The Solution

### Install PIL/Tk Bindings

For RHEL/Fedora-based systems:
```bash
sudo dnf install python3-pillow-tk
```

For Debian/Ubuntu-based systems:
```bash
sudo apt install python3-pil.imagetk
```

### Automatic Emoji Detection

Rather than removing emoji entirely (which would affect Windows and macOS users... as well as all the fun of having emojis), I implemented some automatic detection. The app **should** now:

1. Check if running on Wayland (which handles emoji fine)
2. Check for emoji font availability
3. Detects problematic GPU combinations
4. Falls back to ASCII characters when emoji rendering would fail

This is handled by the `Icons` class in `src/utils/icons.py`:

```python
# On systems with emoji support:
Icons.SETTINGS → "Settings ⚙️"
Icons.CHECKBOX_CHECKED → "☑"

# On systems without emoji support:
Icons.SETTINGS → "Settings"
Icons.CHECKBOX_CHECKED → "[x]"
```

### X11 Thread Safety

I also tried to account for some threading issued id seen with X11.
I added X11 initialization fixes in `main.py` that run before any GUI code:

```python
if platform.system() == "Linux":
    os.environ.setdefault("FREETYPE_PROPERTIES", "truetype:interpreter-version=35")
    x11 = ctypes.CDLL("libX11.so.6")
    x11.XInitThreads()
```

## Files Modified

- `main.py` — Added X11 workarounds
- `src/utils/icons.py` — New file for emoji detection and fallback
- `src/utils/image_utils.py` — Defensive PIL imports
- `src/ui/components/sidebar.py` — Uses Icons class
- `src/ui/components/game_list.py` — Uses Icons class
- `src/ui/components/queue_panel.py` — Uses Icons class

## Manual Override

If you want to force ASCII mode even on systems that pass emoji detection:

```bash
export ROMIFLEUR_NO_EMOJI=1
python3 main.py
```

## Affected Configurations

These fixes specifically address issues seen on:
- **OS:** RHEL 9.x, Fedora, and similar
- **Graphics:** Intel Alder Lake-P, Raptor Lake integrated graphics
- **Display Server:** X11 (Wayland users are unaffected)
- **Python:** 3.9+

Windows and macOS users should see no change in behavior—they'll continue to see emoji as before.
