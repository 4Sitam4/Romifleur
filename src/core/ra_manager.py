
import requests
import json
import os
import re
from .config_manager import ConfigManager

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
        # Cache file in data directory
        data_dir = os.path.dirname(self.config.settings_file) if os.path.isabs(self.config.settings_file) else os.path.join(os.getcwd(), "data") 
        # Actually ConfigManager handles this logic properly? 
        # Let's trust ConfigManager to give us a safe place or just use "data/ra_cache.json"
        
        self.cache_file = os.path.join(os.getcwd(), "data", "ra_cache.json")
        self.cache = self._load_cache()
        
    @property
    def api_key(self):
        return self.config.settings.get("ra_api_key", "")

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
            os.makedirs(os.path.dirname(self.cache_file), exist_ok=True)
            with open(self.cache_file, 'w', encoding='utf-8') as f:
                json.dump(self.cache, f, indent=4)
        except Exception as e:
            print(f"Error saving RA cache: {e}")

    def get_console_id(self, console_key):
        if console_key == "NeoGeo": 
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
            
            simplified = [{"Title": g["Title"], "ID": g["ID"]} for g in data]
            
            self.cache[str_id] = simplified
            self._save_cache()
            return simplified
            
        except Exception as e:

            print(f"RA API Error: {e}")
            return []

    def get_game_details(self, game_id):
        """Fetch extended game details (Cover, Desc, Released)."""
        if not self.api_key: return None
        
        # Check cache? Typically we might want to cache this too, but MetadataManager will likely handle the high-level caching.
        # However, RA Manager could cache raw responses.
        # For now let's just fetch.
        try:
            url = f"{self.BASE_URL}/API_GetGame.php"
            params = {"y": self.api_key, "i": game_id}
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"RA Details Error: {e}")
            return None


    def get_supported_games(self, console_key):
        cid = self.get_console_id(console_key)
        if not cid: return []
        return self.fetch_game_list(cid)

    def is_compatible(self, filename, ra_games):
        """Check if filename likely matches a game in the RA list."""
        clean_name = os.path.splitext(filename)[0]
        clean_name = re.sub(r'\s*[\(\[].*?[\)\]]', '', clean_name).strip().lower()
        
        for game in ra_games:
            ra_title = game["Title"].lower()
            ra_title = re.sub(r'\s*[\(\[].*?[\)\]]', '', ra_title).strip()
            
            if clean_name == ra_title:
                return True
                
            if len(clean_name) > 10 and clean_name in ra_title:
                return True
                
                
        return False

    def validate_key(self, api_key):
        """Check if the provided API Key is valid."""
        if not api_key:
            return False
            
        try:
            # API_GetConsoleIDs is a lightweight component to test auth
            url = f"{self.BASE_URL}/API_GetConsoleIDs.php"
            params = {"y": api_key}
            
            response = requests.get(url, params=params, timeout=5)
            response.raise_for_status()
            
            data = response.json()
            # Valid response is a list of Console dictionaries
            return isinstance(data, list) and len(data) > 0
            
        except Exception as e:
            print(f"Validation Error: {e}")
            return False
