"""
RetroAchievements Manager - Adapted for FastAPI backend
Handles integration with RetroAchievements API for game compatibility.
"""
import os
import re
import json
import logging
from typing import List, Dict, Optional

import requests

from .config_manager import ConfigManager

logger = logging.getLogger(__name__)


class RetroAchievementsManager:
    BASE_URL = "https://retroachievements.org/API"
    
    # Mapping Romifleur Console Names -> RA Console IDs
    CONSOLE_MAP = {
        "NES": 7,
        "SNES": 3,
        "N64": 2,
        "GameCube": 16,
        "GB": 4,
        "GBC": 6,
        "GBA": 5,
        "NDS": 18,
        "MasterSystem": 11,
        "MegaDrive": 1,
        "Saturn": 39,
        "Dreamcast": 40,
        "GameGear": 15,
        "PS1": 12,
        "PSP": 41,
        "PS2": 21,
        "NeoGeo": 24,
        "PC_Engine": 8,
        "Atari2600": 25,
        "Wii": 19,
        "3DS": 62,
    }

    def __init__(self, config_manager: ConfigManager):
        self.config = config_manager
        self.cache_file = os.path.join(self.config.data_dir, "ra_cache.json")
        self.cache = self._load_cache()
        
    @property
    def api_key(self) -> str:
        return self.config.settings.get("ra_api_key", "")

    def _load_cache(self) -> Dict:
        try:
            if os.path.exists(self.cache_file):
                with open(self.cache_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception as e:
            logger.warning(f"Error loading RA cache: {e}")
        return {}

    def _save_cache(self):
        try:
            os.makedirs(os.path.dirname(self.cache_file), exist_ok=True)
            with open(self.cache_file, 'w', encoding='utf-8') as f:
                json.dump(self.cache, f, indent=4)
        except Exception as e:
            logger.error(f"Error saving RA cache: {e}")

    def get_console_id(self, console_key: str) -> Optional[int]:
        """Get RA console ID from Romifleur console key."""
        if console_key == "NeoGeo":
            return 29  # Neo Geo Pocket Color
        return self.CONSOLE_MAP.get(console_key)

    def fetch_game_list(self, console_id: int) -> List[Dict]:
        """Fetch game list from RA API or cache."""
        if not self.api_key:
            return []

        str_id = str(console_id)
        if str_id in self.cache:
            logger.debug(f"Using cached RA list for console {console_id}")
            return self.cache[str_id]

        logger.info(f"Fetching RA list for Console ID {console_id}")
        try:
            url = f"{self.BASE_URL}/API_GetGameList.php"
            params = {
                "y": self.api_key,
                "i": console_id,
                "f": 1  # Only games with achievements
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            # Simplify to just Title and ID
            simplified = [{"Title": g["Title"], "ID": g["ID"]} for g in data]
            
            self.cache[str_id] = simplified
            self._save_cache()
            
            logger.info(f"Fetched {len(simplified)} games from RA")
            return simplified
            
        except Exception as e:
            logger.error(f"RA API Error: {e}")
            return []

    def get_game_details(self, game_id: int) -> Optional[Dict]:
        """Fetch extended game details (cover, description, release date)."""
        if not self.api_key:
            return None
        
        try:
            url = f"{self.BASE_URL}/API_GetGame.php"
            params = {"y": self.api_key, "i": game_id}
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"RA Details Error: {e}")
            return None

    def get_supported_games(self, console_key: str) -> List[Dict]:
        """Get list of games with RetroAchievements for a console."""
        cid = self.get_console_id(console_key)
        if not cid:
            return []
        return self.fetch_game_list(cid)

    def is_compatible(self, filename: str, ra_games: List[Dict]) -> bool:
        """Check if filename likely matches a game in the RA list."""
        clean_name = os.path.splitext(filename)[0]
        clean_name = re.sub(r'\s*[\(\[].*?[\)\]]', '', clean_name).strip().lower()
        
        for game in ra_games:
            ra_title = game["Title"].lower()
            ra_title = re.sub(r'\s*[\(\[].*?[\)\]]', '', ra_title).strip()
            
            # Exact match
            if clean_name == ra_title:
                return True
            
            # Partial match for longer names
            if len(clean_name) > 10 and clean_name in ra_title:
                return True
                
        return False

    def check_rom_compatibility(self, console_key: str, filename: str) -> bool:
        """Check if a specific ROM has RetroAchievements."""
        ra_games = self.get_supported_games(console_key)
        return self.is_compatible(filename, ra_games)

    def validate_key(self, api_key: str) -> bool:
        """Validate a RetroAchievements API key."""
        if not api_key:
            return False
            
        try:
            # Use lightweight endpoint to test auth
            url = f"{self.BASE_URL}/API_GetConsoleIDs.php"
            params = {"y": api_key}
            
            response = requests.get(url, params=params, timeout=5)
            response.raise_for_status()
            
            data = response.json()
            # Valid response is a list of console dictionaries
            return isinstance(data, list) and len(data) > 0
            
        except Exception as e:
            logger.error(f"Key validation error: {e}")
            return False
