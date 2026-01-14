"""
Icon/Emoji support with automatic fallback for X11 compatibility.
Detects if emoji rendering is likely to work and provides ASCII alternatives.
"""

import os
import platform
import subprocess


def _check_emoji_support():
    """
    Detect if emoji rendering is likely to work.
    Returns False for X11 on Linux without proper emoji font support.
    """
    if platform.system() != "Linux":
        return True  # Windows/macOS generally handle emoji fine
    
    # Check for manual override
    if os.environ.get("ROMIFLEUR_NO_EMOJI", "").lower() in ("1", "true", "yes"):
        return False
    
    # Check if running on Wayland (usually better emoji support)
    session_type = os.environ.get("XDG_SESSION_TYPE", "").lower()
    if session_type == "wayland":
        return True
    
    # On X11, check for emoji fonts
    try:
        result = subprocess.run(
            ["fc-list", ":charset=1F600"],  # Check for grinning face emoji
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0 and result.stdout.strip():
            # Has emoji fonts, but X11 + certain Intel GPUs still have issues
            # Check for problematic Intel graphics
            try:
                lspci = subprocess.run(["lspci"], capture_output=True, text=True, timeout=5)
                if "Alder Lake" in lspci.stdout or "Raptor Lake" in lspci.stdout:
                    return False  # Known problematic with X11 emoji rendering
            except Exception:
                pass
            return True
    except Exception:
        pass
    
    return False  # Default to safe ASCII on X11 Linux


EMOJI_SUPPORTED = _check_emoji_support()


class Icons:
    """Icons that fall back to ASCII if emoji not supported."""
    if EMOJI_SUPPORTED:
        SETTINGS = "Settings ⚙️"
        ROCKET = "Start Downloads 🚀"
        REMOVE = "❌"
        TROPHY = "🏆"
        NO_TROPHY = "❌"
        CHECKBOX_EMPTY = "☐"
        CHECKBOX_CHECKED = "☑"
        ARROW_RIGHT = "Add to Queue ➡️"
        SAVE = "Save 💾"
        FOLDER = "Load 📂"
        TRASH = "Clear All 🗑️"
        EXPAND = "▼"  # Down triangle
        COLLAPSE = "▶"  # Right triangle
    else:
        SETTINGS = "Settings"
        ROCKET = "Start Downloads"
        REMOVE = "X"
        TROPHY = "Y"
        NO_TROPHY = "-"
        CHECKBOX_EMPTY = "[ ]"
        CHECKBOX_CHECKED = "[x]"
        ARROW_RIGHT = "Add to Queue"
        SAVE = "Save"
        FOLDER = "Load"
        TRASH = "Clear All"
        EXPAND = "v"
        COLLAPSE = ">"
