
import requests
from bs4 import BeautifulSoup
from urllib.parse import unquote
import re
import os
from .config_manager import ConfigManager

class RomManager:
    def __init__(self, config_manager: ConfigManager):
        self.config = config_manager
        self.consoles = self.config.consoles
        self.cache = {} # {console_key: [list of files]}
        self.filters = {
            "region": ["(Europe)", "(France)", "(Fr)"],
            "exclude": ["(Demo)", "(Beta)", "(Proto)", "(Kiosk)", "(Sample)", "(Unl)"],
            "deduplicate": True
        }

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
                        # Try to find size
                        size = "N/A"
                        # Strategy 1: Table based (Myrient often uses tables)
                        parent_td = link.find_parent('td')
                        if parent_td:
                            # Usually Date is next, then Size, or just Size. 
                            # Myrient: Name | Date | Size
                            next_tds = parent_td.find_next_siblings('td')
                            for td in next_tds:
                                text = td.get_text(strip=True)
                                # Look for size pattern (digits + B/K/M/G)
                                if re.search(r'\d+(\.\d+)?\s*[BKMG]i?B?', text, re.IGNORECASE):
                                    size = text
                                    break
                        
                        # Strategy 2: Text based (Apache/Nginx standard)
                        if size == "N/A":
                            next_text = link.next_sibling
                            if next_text and isinstance(next_text, str):
                                # "           01-Jan-2022 12:00  1.2M"
                                # Find last parsed chunk usually
                                parts = next_text.strip().split()
                                if parts:
                                    # Check last part for size-like
                                    candidate = parts[-1]
                                    if re.match(r'^[\d\.]+[BKMG]$', candidate):
                                        size = candidate

                        links.append({"name": filename, "size": size})
            
            self.cache[cache_key] = links
            return links
        except Exception as e:
            print(f"Error fetching {console_key}: {e}")
            return []

    def search(self, category, console_key, query=""):
        """Searches within a console's file list, applying filters."""
        files = self.fetch_file_list(category, console_key)
        
        filtered = []
        for item in files:
            f = item["name"] # Extract name for filtering logic
            
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

            # 3. Region Filter
            if self.filters["region"]:
                is_region_match = False
                file_tags = []
                param_groups = re.findall(r'\((.*?)\)', f)
                for group in param_groups:
                    parts = [p.strip().lower() for p in group.split(',')]
                    file_tags.extend(parts)
                
                for r in self.filters["region"]:
                    clean_r = r.lower().replace('(', '').replace(')', '').strip()
                    if clean_r in file_tags:
                        is_region_match = True
                        break
                    
                if not is_region_match:
                    continue
            
                    if clean_r in file_tags:
                        is_region_match = True
                        break
                    
                if not is_region_match:
                    continue
            
            filtered.append(item) # Append the full dict object

        if self.filters["deduplicate"]:
            filtered = self._deduplicate(filtered)
            
        return filtered

    def _deduplicate(self, file_list):
        """Deduplicates list keeping best revisions."""
        best_candidates = {}
        for item in file_list:
            filename = item["name"]
            base = self._get_base_title(filename)
            score = self._get_score(filename)
            
            if base not in best_candidates:
                best_candidates[base] = (score, item)
            else:
                if score > best_candidates[base][0]:
                    best_candidates[base] = (score, item)
                    
        return sorted([val[1] for val in best_candidates.values()], key=lambda x: x["name"])

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
        if "(France)" in filename or "(Fr)" in filename: score += 2
        elif "(Europe)" in filename: score += 1
        if "Virtual Console" in filename: score -= 50
        return score

    def download_file(self, category, console_key, filename, progress_callback=None):
        """Downloads a single file."""
        try:
            config = self.consoles[category][console_key]
            base_url = config['url']
            
            if "myrient" in base_url or "archive.org" in base_url:
                 if not base_url.endswith("/"): base_url += "/"
                 from urllib.parse import quote
                 download_url = base_url + quote(filename)
            else:
                 download_url = base_url + filename
            
            folder_name = config.get('folder', console_key)
            root_path = self.config.get_download_path()
            save_dir = os.path.join(root_path, folder_name)
            
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
            
            if filename.endswith((".zip", ".7z")):
                self._extract(filepath)
                
            if progress_callback: progress_callback(1.0, "Done")
            return True
            
        except Exception as e:
            print(f"Download error: {e}")
            if progress_callback: progress_callback(0, f"Error: {e}")
            return False

    def _extract(self, filepath):
        import zipfile
        import py7zr
        try:
            directory = os.path.dirname(filepath)
            if filepath.endswith(".zip"):
                with zipfile.ZipFile(filepath, 'r') as z: z.extractall(directory)
            elif filepath.endswith(".7z"):
                with py7zr.SevenZipFile(filepath, 'r') as z: z.extractall(directory)
            os.remove(filepath)
        except Exception as e:
            print(f"Extraction error: {e}")
