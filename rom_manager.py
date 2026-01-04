import os
import json
import requests
from bs4 import BeautifulSoup
from urllib.parse import unquote
import re
import threading
import time

class RomManager:
    def __init__(self, catalog_path="consoles.json"):
        self.catalog_path = catalog_path
        self.consoles = self._load_catalog()
        self.cache = {} # {console_key: [list of files]}
        self.filters = {
            "region": ["(Europe)", "(France)", "(Fr)"],
            "exclude": ["(Demo)", "(Beta)", "(Proto)", "(Kiosk)", "(Sample)", "(Unl)"],
            "deduplicate": True
        }

    def _load_catalog(self):
        import sys
        
        def resource_path(relative_path):
            """ Get absolute path to resource, works for dev and for PyInstaller """
            try:
                # PyInstaller creates a temp folder and stores path in _MEIPASS
                base_path = sys._MEIPASS
            except Exception:
                base_path = os.path.abspath(".")
            return os.path.join(base_path, relative_path)

        try:
            # Use resource_path to find the json file inside the bundle
            path = resource_path(self.catalog_path)
            with open(path, 'r') as f:
                data = json.load(f)
            return data
        except FileNotFoundError:
            return {}

    def get_console_list(self):
        """Returns a list of (Category, ConsoleKey, Name)"""
        flat_list = []
        for category, consoles in self.consoles.items():
            for key, data in consoles.items():
                flat_list.append((category, key, data['name']))
        return flat_list

    def fetch_file_list(self, category, console_key, force_reload=False):
        """Fetches file list from URL, with caching."""
        cache_key = f"{category}_{console_key}"
        if not force_reload and cache_key in self.cache:
            return self.cache[cache_key]

        try:
            config = self.consoles.get(category, {}).get(console_key)
            if not config: return []
            
            url = config['url']
            exts = tuple(config['exts'])
            
            print(f"Fetching {url}...")
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            links = []
            
            for link in soup.find_all('a'):
                href = link.get('href')
                if href and href.endswith(exts):
                    filename = unquote(href)
                    if filename not in [".", ".."]:
                         links.append(filename)
            
            self.cache[cache_key] = links
            return links
        except Exception as e:
            print(f"Error fetching {console_key}: {e}")
            return []

    def search(self, category, console_key, query=""):
        """Searches within a console's file list, applying filters."""
        files = self.fetch_file_list(category, console_key)
        
        filtered = []
        for f in files:
            # 1. Query Filter
            if query and query.lower() not in f.lower():
                continue
            
            # 2. Exclude Filter
            is_excluded = False
            for ex in self.filters["exclude"]:
                if ex.lower() in f.lower():
                    is_excluded = True
                    break
            if is_excluded: continue

            # 3. Region Filter (Strict if list is not empty)
            if self.filters["region"]:
                is_region_match = False
                for r in self.filters["region"]:
                     if r.lower() in f.lower():
                         is_region_match = True
                         break
                if not is_region_match:
                    continue
            
            filtered.append(f)

        # 3. Deduplication (Optional, can be heavy for large lists in real-time)
        if self.filters["deduplicate"]:
            filtered = self._deduplicate(filtered)
            
        return filtered

    def _deduplicate(self, file_list):
        """Deduplicates list keeping best revisions."""
        # Map: BaseTitle -> (Score, Filename)
        best_candidates = {}
        
        for filename in file_list:
            base = self._get_base_title(filename)
            score = self._get_score(filename)
            
            if base not in best_candidates:
                best_candidates[base] = (score, filename)
            else:
                if score > best_candidates[base][0]:
                    best_candidates[base] = (score, filename)
                    
        return sorted([val[1] for val in best_candidates.values()])

    def _get_base_title(self, filename):
        name = os.path.splitext(filename)[0]
        def replace_params(match):
            c = match.group(0).lower()
            if "disc" in c or "disk" in c: return c
            return ""
        return re.sub(r'\s*\([^)]+\)', replace_params, name).strip()

    def _get_score(self, filename):
        score = 0
        file_lower = filename.lower()
        
        # Region Preference
        if "(France)" in filename or "(Fr)" in filename:
            score += 2
        elif "(Europe)" in filename:
            score += 1
            
        # Penalize Virtual Console
        if "Virtual Console" in filename:
            score -= 50
            
        return score

    def download_file(self, category, console_key, filename, progress_callback=None):
        """Downloads a single file with progress updates."""
        try:
            config = self.consoles[category][console_key]
            base_url = config['url']
            # Myrient/Archive handling
            if "myrient" in base_url or "archive.org" in base_url:
                 # Ensure proper URL joining
                 if not base_url.endswith("/"): base_url += "/"
                 # Filenames in hrefs are usually urlencoded, but here we have the decoded filename
                 # We need to quote it back for the request, BUT Requests handles this if we passparams?
                 # Actually simply quoting the filename component is safest.
                 from urllib.parse import quote
                 download_url = base_url + quote(filename)
            else:
                 download_url = base_url + filename # Fallback
            
            # Use 'folder' from config if available, else console_key
            folder_name = config.get('folder', console_key)
            save_dir = os.path.join("ROMs", folder_name)
            
            os.makedirs(save_dir, exist_ok=True)
            filepath = os.path.join(save_dir, filename)
            
            if os.path.exists(filepath):
                if progress_callback: progress_callback(1.0, "Exists")
                return True

            response = requests.get(download_url, stream=True, timeout=30)
            response.raise_for_status()
            
            total = int(response.headers.get('content-length', 0))
            downloaded = 0
            
            with open(filepath + ".tmp", 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        if progress_callback and total > 0:
                            progress_callback(downloaded / total, f"{downloaded/1024/1024:.1f} MB")
            
            os.replace(filepath + ".tmp", filepath)
            
            # Extraction logic could go here
            if filename.endswith((".zip", ".7z")):
                self._extract(filepath)
                
            if progress_callback: progress_callback(1.0, "Done")
            return True
            
        except Exception as e:
            print(f"Download error: {e}")
            if progress_callback: progress_callback(0, f"Error: {e}")
            return False

    def _extract(self, filepath):
        # reuse extraction logic
        import zipfile
        import py7zr
        try:
            directory = os.path.dirname(filepath)
            if filepath.endswith(".zip"):
                with zipfile.ZipFile(filepath, 'r') as z: z.extractall(directory)
            elif filepath.endswith(".7z"):
                with py7zr.SevenZipFile(filepath, 'r') as z: z.extractall(directory)
            os.remove(filepath) # Cleanup
        except Exception as e:
            print(f"Extraction error: {e}")
