"""
Configuration Manager - Adapted for FastAPI backend
Handles user settings and console catalog loading.
"""
import os
import json
import sys
import logging
from pathlib import Path

logger = logging.getLogger(__name__)


class ConfigManager:
    def __init__(self, settings_file: str = "settings.json", consoles_file: str = "consoles.json"):
        self.settings_file = settings_file
        self.consoles_file = consoles_file
        
        # Determine base data directory
        self.data_dir = self._get_data_dir()
        os.makedirs(self.data_dir, exist_ok=True)
        
        self.settings = self.load_settings()
        self.consoles = self.load_consoles()

    def _get_data_dir(self) -> str:
        """Get the data directory for storing settings and cache."""
        # Check for PyInstaller bundle
        if getattr(sys, 'frozen', False):
            # Running as compiled - use app directory
            base = os.path.dirname(sys.executable)
        else:
            # Running as script - use backend directory
            base = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        
        return os.path.join(base, "data")

    def get_resource_path(self, relative_path: str) -> str:
        """Get absolute path to resource, works for dev and PyInstaller."""
        try:
            # PyInstaller creates a temp folder and stores path in _MEIPASS
            base_path = sys._MEIPASS
        except AttributeError:
            # Running from source - check backend/app directory
            base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        return os.path.join(base_path, relative_path)

    def load_settings(self) -> dict:
        """Load user settings from JSON file."""
        path = os.path.join(self.data_dir, self.settings_file)
        
        try:
            if os.path.exists(path):
                with open(path, "r", encoding="utf-8") as f:
                    return json.load(f)
        except Exception as e:
            logger.error(f"Error loading settings: {e}")
        
        # Default settings
        return {"roms_path": str(Path.home() / "ROMs"), "ra_api_key": ""}

    def save_settings(self) -> bool:
        """Save user settings to JSON file."""
        path = os.path.join(self.data_dir, self.settings_file)
        
        try:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                json.dump(self.settings, f, indent=4)
            return True
        except Exception as e:
            logger.error(f"Error saving settings: {e}")
            return False

    def load_consoles(self) -> dict:
        """Load static console catalog from JSON file."""
        paths_to_try = [
            self.get_resource_path(os.path.join("data", self.consoles_file)),
            self.get_resource_path(self.consoles_file),
            os.path.join(self.data_dir, self.consoles_file),
            # Also check old location for backwards compatibility
            os.path.join(os.path.dirname(self.data_dir), "config", self.consoles_file),
        ]
        
        for path in paths_to_try:
            try:
                if os.path.exists(path):
                    with open(path, 'r', encoding='utf-8') as f:
                        logger.info(f"Loaded consoles from: {path}")
                        return json.load(f)
            except Exception as e:
                logger.warning(f"Failed to load consoles from {path}: {e}")
        
        logger.error("Could not find consoles.json in any location")
        return {}

    def get_download_path(self) -> str:
        """Get and ensure download path exists."""
        path = self.settings.get("roms_path", str(Path.home() / "ROMs"))
        
        if not os.path.isabs(path):
            path = os.path.abspath(path)
        
        if not os.path.exists(path):
            try:
                os.makedirs(path, exist_ok=True)
            except Exception:
                # Fallback to home directory
                default = str(Path.home() / "ROMs")
                os.makedirs(default, exist_ok=True)
                return default
        
        return path

    def update_settings(self, roms_path: str = None, ra_api_key: str = None) -> bool:
        """Update specific settings."""
        if roms_path is not None:
            self.settings["roms_path"] = roms_path
        if ra_api_key is not None:
            self.settings["ra_api_key"] = ra_api_key
        return self.save_settings()
