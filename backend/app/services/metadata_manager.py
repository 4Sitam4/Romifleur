"""
Metadata Manager - Adapted for FastAPI backend
Fetches game metadata from TheGamesDB API with caching.
"""
import os
import re
import json
import logging
from typing import Dict, Optional

import requests

from .config_manager import ConfigManager
from .ra_manager import RetroAchievementsManager

logger = logging.getLogger(__name__)


class MetadataManager:
    # TheGamesDB public API key
    TGDB_API_KEY = "60618838ba6187bceb6cef061e6d207f44773204f247f01e62901caff3ede5f7"
    
    # Map console keys from consoles.json to TGDB Platform IDs
    PLATFORM_MAP = {
        "NES": 7, "SNES": 6, "N64": 3, "GameCube": 2,
        "GB": 4, "GBC": 41, "GBA": 5, "NDS": 8, "3DS": 4912,
        "MasterSystem": 35, "MegaDrive": 18, "Saturn": 17, "Dreamcast": 16, "GameGear": 20,
        "PS1": 10, "PSP": 13, "PS2": 11,
        "NeoGeo": 4923, "PC_Engine": 34, "Atari2600": 22
    }

    def __init__(self, config_manager: ConfigManager, ra_manager: RetroAchievementsManager):
        self.config = config_manager
        self.ra = ra_manager
        
        self.cache_file = os.path.join(self.config.data_dir, "metadata_cache.json")
        self.mappings_file = os.path.join(self.config.data_dir, "tgdb_mappings.json")
        
        self.cache = self._load_cache()
        self.mappings = self._load_mappings()

    def _load_cache(self) -> Dict:
        try:
            if os.path.exists(self.cache_file):
                with open(self.cache_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception as e:
            logger.warning(f"Error loading metadata cache: {e}")
        return {}

    def _save_cache(self):
        try:
            os.makedirs(os.path.dirname(self.cache_file), exist_ok=True)
            with open(self.cache_file, 'w', encoding='utf-8') as f:
                json.dump(self.cache, f, indent=4)
        except Exception as e:
            logger.error(f"Error saving metadata cache: {e}")

    def _load_mappings(self) -> Dict:
        try:
            if os.path.exists(self.mappings_file):
                with open(self.mappings_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception as e:
            logger.warning(f"Error loading TGDB mappings: {e}")
        return {"genres": {}, "developers": {}, "publishers": {}}

    def _save_mappings(self):
        try:
            with open(self.mappings_file, 'w', encoding='utf-8') as f:
                json.dump(self.mappings, f)
        except Exception as e:
            logger.error(f"Error saving TGDB mappings: {e}")

    def get_metadata(self, console_key: str, filename: str) -> Dict:
        """
        Fetch game metadata for a ROM file.
        Returns dict with: title, description, date, image_url, provider, etc.
        """
        cache_key = f"{console_key}|{filename}"
        if cache_key in self.cache:
            return self.cache[cache_key]
        
        # Clean title from filename
        clean_title = self._clean_filename(filename)
        
        # Default result
        data = {
            "title": clean_title,
            "description": "No description available.",
            "date": "Unknown",
            "image_url": None,
            "provider": "Local",
            "has_achievements": False
        }
        
        # Check RetroAchievements compatibility
        data["has_achievements"] = self.ra.check_rom_compatibility(console_key, filename)
        
        # Try TheGamesDB
        tgdb_data = self._fetch_tgdb(console_key, filename)
        if tgdb_data:
            data.update(tgdb_data)
        
        # Cache result
        self.cache[cache_key] = data
        self._save_cache()
        
        return data

    def _clean_filename(self, filename: str) -> str:
        """Extract clean game title from filename."""
        name = os.path.splitext(filename)[0]
        name = re.sub(r'\s*[\(\[].*?[\)\]]', '', name)
        return name.strip()

    def _get_platform_id(self, console_key: str) -> Optional[int]:
        """Get TGDB platform ID from console key."""
        return self.PLATFORM_MAP.get(console_key)

    def _ensure_mappings(self):
        """Fetch TGDB mappings (genres, developers, publishers) if not cached."""
        headers = {"User-Agent": "Romifleur/2.0", "Accept": "application/json"}
        
        if not self.mappings.get("genres"):
            try:
                resp = requests.get(
                    f"https://api.thegamesdb.net/v1/Genres?apikey={self.TGDB_API_KEY}",
                    headers=headers, timeout=5
                )
                if resp.status_code == 200:
                    data = resp.json()
                    self.mappings["genres"] = {
                        str(g["id"]): g["name"] 
                        for g in data["data"]["genres"].values()
                    }
                    self._save_mappings()
            except Exception as e:
                logger.warning(f"Genre fetch error: {e}")

        if not self.mappings.get("developers"):
            try:
                resp = requests.get(
                    f"https://api.thegamesdb.net/v1/Developers?apikey={self.TGDB_API_KEY}",
                    headers=headers, timeout=5
                )
                if resp.status_code == 200:
                    data = resp.json()
                    self.mappings["developers"] = {
                        str(d["id"]): d["name"] 
                        for d in data["data"]["developers"].values()
                    }
                    self._save_mappings()
            except Exception as e:
                logger.warning(f"Developer fetch error: {e}")

        if not self.mappings.get("publishers"):
            try:
                resp = requests.get(
                    f"https://api.thegamesdb.net/v1/Publishers?apikey={self.TGDB_API_KEY}",
                    headers=headers, timeout=5
                )
                if resp.status_code == 200:
                    data = resp.json()
                    self.mappings["publishers"] = {
                        str(p["id"]): p["name"] 
                        for p in data["data"]["publishers"].values()
                    }
                    self._save_mappings()
            except Exception as e:
                logger.warning(f"Publisher fetch error: {e}")

    def _get_mapping_name(self, map_type: str, id_val) -> str:
        """Get name from mapping by ID."""
        return self.mappings.get(map_type, {}).get(str(id_val), "Unknown")

    def _fetch_tgdb(self, console_key: str, filename: str) -> Optional[Dict]:
        """Fetch metadata from TheGamesDB API."""
        platform_id = self._get_platform_id(console_key)
        if not platform_id:
            logger.debug(f"Unknown Platform ID for {console_key}")
            return None
        
        clean_name = self._clean_filename(filename)
        
        # Ensure mappings are loaded
        self._ensure_mappings()
        
        try:
            url = "https://api.thegamesdb.net/v1/Games/ByGameName"
            params = {
                "apikey": self.TGDB_API_KEY,
                "name": clean_name,
                "fields": "overview,publishers,developers,genres,release_date,players,rating",
                "filter[platform]": platform_id,
                "include": "boxart"
            }
            headers = {"User-Agent": "Romifleur/2.0", "Accept": "application/json"}
            
            resp = requests.get(url, params=params, headers=headers, timeout=10)
            
            if resp.status_code != 200:
                logger.warning(f"TGDB Error {resp.status_code}: {resp.text}")
                return None
            
            data = resp.json()
            
            # Check for games data
            if not data.get("data") or not data["data"].get("games"):
                return None
            
            # Get first match
            game = data["data"]["games"][0]
            game_id = game["id"]
            
            # Extract image URL
            image_url = None
            if data.get("include") and data["include"].get("boxart"):
                boxart_info = data["include"]["boxart"]
                base_url = boxart_info.get("base_url", {}).get("medium")
                images_map = boxart_info.get("data", {})
                game_images = images_map.get(str(game_id)) or images_map.get(game_id)
                
                if base_url and game_images:
                    for art in game_images:
                        if art.get("side") == "front":
                            image_url = f"{base_url}{art['filename']}"
                            break
            
            # Map IDs to names
            genres_list = [self._get_mapping_name("genres", g_id) for g_id in game.get("genres", [])]
            devs_list = [self._get_mapping_name("developers", d_id) for d_id in game.get("developers", [])]
            pubs_list = [self._get_mapping_name("publishers", p_id) for p_id in game.get("publishers", [])]
            
            return {
                "title": game.get("game_title", clean_name),
                "description": game.get("overview", "No description."),
                "date": game.get("release_date", "Unknown"),
                "image_url": image_url,
                "provider": "TheGamesDB",
                "genres": ", ".join(genres_list) if genres_list else "Unknown",
                "developer": ", ".join(devs_list) if devs_list else "Unknown",
                "publisher": ", ".join(pubs_list) if pubs_list else "Unknown",
                "players": str(game.get("players", "Unknown")),
                "rating": game.get("rating", "Unknown")
            }
            
        except Exception as e:
            logger.error(f"TGDB Error: {e}")
            return None
