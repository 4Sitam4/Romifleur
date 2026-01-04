import requests
import json
import os
import re
from difflib import SequenceMatcher

class RetroAchievementsManager:
    BASE_URL = "https://retroachievements.org/API"
    
    # Mapping Renifleur Console Names -> RA Console IDs
    CONSOLE_MAP = {
        "NES": 7,
        "SNES": 9,
        "N64": 2,
        "GameCube": 3,
        "GB": 4,
        "GBC": 6,
        "GBA": 5,
        "NDS": 8,
        "MasterSystem": 13,
        "MegaDrive": 1,
        "Saturn": 17,
        "Dreamcast": 16,
        "GameGear": 20,
        "PS1": 12,
        "PSP": 41,
        "PS2": 21,
        "NeoGeo": 24, # Neo Geo Pocket (Color is distinct on RA? let's check)
        # NGPC is ID 29 on RA usually
        "PC_Engine": 10,
        "Atari2600": 25,
        "Wii": 35,
        "3DS": 102 # Check ID
    }

    def __init__(self, api_key=None):
        self.api_key = api_key
        self.cache_file = "ra_cache.json"
        self.cache = self._load_cache()
        
    def _load_cache(self):
        try:
            if os.path.exists(self.cache_file):
                with open(self.cache_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception:
            pass
        return {}

    def _save_cache(self):
        try:
            with open(self.cache_file, 'w', encoding='utf-8') as f:
                json.dump(self.cache, f, indent=4)
        except Exception as e:
            print(f"Error saving RA cache: {e}")

    def get_console_id(self, console_key):
        # Handle special cases if needed
        if console_key == "NeoGeo": # Renifleur's NeoGeo is actually NGPC url
            return 29 # Neo Geo Pocket Color
        return self.CONSOLE_MAP.get(console_key)

    def fetch_game_list(self, console_id):
        """Fetch game list from RA API or Cache."""
        if not self.api_key:
            return []

        str_id = str(console_id)
        if str_id in self.cache:
            return self.cache[str_id]

        print(f"Fetching RA list for Console ID {console_id}...")
        try:
            url = f"{self.BASE_URL}/API_GetGameList.php"
            params = {
                "y": self.api_key,
                "i": console_id,
                "f": 1 # Only games with achievements
            }
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            data = response.json()
            
            # Simplify data for cache: Title only is enough for matching?
            # Or Title + ID
            simplified = [{"Title": g["Title"], "ID": g["ID"]} for g in data]
            
            self.cache[str_id] = simplified
            self._save_cache()
            return simplified
            
        except Exception as e:
            print(f"RA API Error: {e}")
            return []

    def get_supported_games(self, console_key):
        cid = self.get_console_id(console_key)
        if not cid: return []
        return self.fetch_game_list(cid)

    def is_compatible(self, filename, ra_games):
        """
        Check if filename likely matches a game in the RA list.
        Uses basic cleaning and fuzzy matching.
        """
        # 1. Clean filename (remove extension, regions, tags)
        clean_name = os.path.splitext(filename)[0]
        # Remove (...) and [...] tags
        clean_name = re.sub(r'\s*[\(\[].*?[\)\]]', '', clean_name).strip().lower()
        
        # 2. Heuristic Check
        # Most No-Intro names match RA titles closely.
        for game in ra_games:
            ra_title = game["Title"].lower()
            # Remove tags from RA title too if any
            ra_title = re.sub(r'\s*[\(\[].*?[\)\]]', '', ra_title).strip()
            
            if clean_name == ra_title:
                return True
                
            # If standard exact match fails, try simple inclusion for long titles
            if len(clean_name) > 10 and clean_name in ra_title:
                return True
                
        return False
