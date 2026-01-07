import os
import json
import requests
import re
from urllib.parse import quote
from datetime import datetime
from .ra_manager import RetroAchievementsManager

class MetadataManager:
    def __init__(self, config_manager, ra_manager: RetroAchievementsManager):
        self.config = config_manager
        self.ra = ra_manager
        
        self.cache_file = os.path.join(os.getcwd(), "data", "metadata_cache.json")
        self.cache = self._load_cache()
        
        # Mappings cache (loaded on demand)
        self.mappings_file = os.path.join(os.getcwd(), "data", "tgdb_mappings.json")
        self.mappings = self._load_mappings()
        
        # # TGDB Platform ID Map (Name from consoles.json -> TGDB ID)
        # self.platform_map = {
        #     "Nintendo Entertainment System": 7,
        #     "Super Nintendo": 6,
        #     "Nintendo 64": 3,
        #     "GameCube": 2,
        #     "Game Boy": 4,
        #     "Game Boy Color": 41,
        #     "Game Boy Advance": 5,
        #     "Nintendo DS": 8,
        #     "Nintendo 3DS": 4912,
        #     "Master System": 35,
        #     "Mega Drive / Genesis": 18,
        #     "Sega Saturn": 17,
        #     "Dreamcast": 16,
        #     "Game Gear": 20,
        #     "PlayStation 1": 10,
        #     "PlayStation Portable": 13,
        #     "PlayStation 2": 11,
        #     "Neo Geo Pocket Color": 4923,
        #     "PC Engine / TurboGrafx-16": 34,
        #     "Atari 2600": 22
        # }
        
    def _load_cache(self):
        try:
            if os.path.exists(self.cache_file):
                with open(self.cache_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except:
            pass
        return {}
        
    def _save_cache(self):
        try:
            os.makedirs(os.path.dirname(self.cache_file), exist_ok=True)
            with open(self.cache_file, 'w', encoding='utf-8') as f:
                json.dump(self.cache, f, indent=4)
        except Exception as e:
            print(f"Error saving metadata cache: {e}")

    def get_metadata(self, console, filename):
        """
        Orchestrates fetching metadata.
        Returns dict: {
            "title": str,
            "description": str,
            "date": str,
            "image_url": str, # or local path
            "provider": str
        }
        """
        cache_key = f"{console}|{filename}"
        if cache_key in self.cache:
            return self.cache[cache_key]
            
        # Clean title
        clean_title = self._clean_filename(filename)
            
        # Result placeholder
        data = {
            "title": clean_title,
            "description": "No description available.",
            "date": "Unknown",
            "image_url": None,
            "provider": "Local"
        }
        
        # 1. Try TheGameDB
        tgdb_key = "60618838ba6187bceb6cef061e6d207f44773204f247f01e62901caff3ede5f7" # Public Key
        
        if tgdb_key:
             tgdb_data = self._fetch_tgdb(console, filename, tgdb_key)

             if tgdb_data:
                data.update(tgdb_data)
                self.cache[cache_key] = data
                self._save_cache()
                return data
        else:
             print("Missing TGDB API Key")

        # Fallback to local (just cleaned title)
            
        # Save local fallback too to avoid re-searching failed games repeatedly?
        # Maybe handle "not found" separately if we want to retry later.
        # For now, saving result.
        self.cache[cache_key] = data
        self._save_cache()
        return data

    def _clean_filename(self, filename):
        name = os.path.splitext(filename)[0]
        name = re.sub(r'\s*[\(\[].*?[\)\]]', '', name)
        return name.strip()

    def _fetch_tgdb(self, console_key, filename, api_key):
        # Console Key is the dictionary key from consoles.json (e.g. "NES", "SNES")
        # We need to map this to TGDB ID.
        # But wait, 'console' argument passed to get_metadata typically comes from selected item.
        # In Sidebar/GameList, we track 'current_console' which is the key (e.g. "NES").
        # However, we need the display name to map? 
        # Actually my map above uses names.
        # Let's check what 'console' is. In GameList it is self.current_console (key).
        # We can access RomManager to get the name from the key.
        
        console_name = "Unknown"
        # Find name from key
        for cat in self.ra.config.get_consoles().values(): # ConfigManager? No, RomManager
             # Re-accessing config raw or passed config manager
             # ConfigManager doesn't seem to store the consoles structure, RomManager does.
             # MetadataManager doesn't have RomManager reference, only RA Manager.
             # But RA manager parses consoles.json too? No, it hardcodes identifiers.
             # Let's peek at ConfigManager or assume we can load existing consoles.json?
             pass
        
        # Simpler: Pass the console NAME to get_metadata? 
        # Or just Map the KEYS directly. This is safer.
        # Let's redefine the map to use KEYS.
        pass

    def _get_platform_id(self, console_key):
        # Map KEYS from consoles.json to TGDB IDs
        # "NES": 7, etc.
        key_map = {
            "NES": 7, "SNES": 6, "N64": 3, "GameCube": 2,
            "GB": 4, "GBC": 41, "GBA": 5, "NDS": 8, "3DS": 4912,
            "MasterSystem": 35, "MegaDrive": 18, "Saturn": 17, "Dreamcast": 16, "GameGear": 20,
            "PS1": 10, "PSP": 13, "PS2": 11,
            "NeoGeo": 4923, "PC_Engine": 34, "Atari2600": 22
        }
        return key_map.get(console_key)

    def _load_mappings(self):
        try:
            if os.path.exists(self.mappings_file):
                with open(self.mappings_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except:
            pass
        return {"genres": {}, "developers": {}, "publishers": {}}

    def _save_mappings(self):
        try:
             with open(self.mappings_file, 'w', encoding='utf-8') as f:
                json.dump(self.mappings, f)
        except:
            pass

    def _ensure_mappings(self, api_key):
        # Helper to fetch mappings if empty
        # We process one type at a time to not block too long
        headers = {"User-Agent": "Romifleur/1.0", "Accept": "application/json"}
        
        if not self.mappings["genres"]:
            try:
                resp = requests.get(f"https://api.thegamesdb.net/v1/Genres?apikey={api_key}", headers=headers, timeout=5)
                if resp.status_code == 200:
                    data = resp.json()
                    self.mappings["genres"] = {str(g["id"]): g["name"] for g in data["data"]["genres"].values()}
                    self._save_mappings()
            except Exception as e:
                print(f"Genre fetch error: {e}")

        # Developers and Publishers might be too large to fetch all at once confidently without blocking UI.
        # But per user request "Minimal requests", fetching once is better than 0.
        # Let's try fetching them if missing.
        if not self.mappings["developers"]:
            try:
                resp = requests.get(f"https://api.thegamesdb.net/v1/Developers?apikey={api_key}", headers=headers, timeout=5)
                if resp.status_code == 200:
                    data = resp.json()
                    self.mappings["developers"] = {str(d["id"]): d["name"] for d in data["data"]["developers"].values()}
                    self._save_mappings()
            except Exception as e:
                print(f"Dev fetch error: {e}")

        if not self.mappings["publishers"]:
            try:
                resp = requests.get(f"https://api.thegamesdb.net/v1/Publishers?apikey={api_key}", headers=headers, timeout=5)
                if resp.status_code == 200:
                    data = resp.json()
                    self.mappings["publishers"] = {str(p["id"]): p["name"] for p in data["data"]["publishers"].values()}
                    self._save_mappings()
            except Exception as e:
                print(f"Pub fetch error: {e}")

    def _get_mapping_name(self, map_type, id_val):
        return self.mappings.get(map_type, {}).get(str(id_val), "Unknown")

    def _fetch_tgdb(self, console_key, filename, api_key):
        platform_id = self._get_platform_id(console_key)
        if not platform_id:
            print(f"Unknown Platform ID for {console_key}")
            return None
            
        clean_name = self._clean_filename(filename)
        
        # Ensure mappings are ready (cached or fetched)
        # This might add a delay on the very first run
        self._ensure_mappings(api_key)
        
        try:
            url = "https://api.thegamesdb.net/v1/Games/ByGameName"
            
            # Request fields including new ones
            params = {
                "apikey": api_key,
                "name": clean_name,
                "fields": "overview,publishers,developers,genres,release_date,players,rating",
                "filter[platform]": platform_id,
                "include": "boxart"
            }
            
            headers = {"User-Agent": "Romifleur/1.0", "Accept": "application/json"}
            
            resp = requests.get(url, params=params, headers=headers, timeout=10)
            
            if resp.status_code != 200:
                print(f"TGDB Error {resp.status_code}: {resp.text}")
                return None
                
            data = resp.json()
            
            # Check for games data
            if not data.get("data") or not data["data"].get("games"):
                return None
                
            # Get the first match
            game = data["data"]["games"][0]
            game_id = game["id"]
            
            # Extract Image
            image_url = None
            if data.get("include") and data["include"].get("boxart"):
                boxart_info = data["include"]["boxart"]
                base_url = boxart_info.get("base_url", {}).get("medium") # Use medium size
                images_map = boxart_info.get("data", {})
                game_images = images_map.get(str(game_id)) or images_map.get(game_id)
                
                if base_url and game_images:
                    for art in game_images:
                        if art.get("side") == "front":
                             image_url = f"{base_url}{art['filename']}"
                             break

            # Map IDs to Names
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
            print(f"TGDB Error: {e}")
            return None


