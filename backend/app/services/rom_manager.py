"""
ROM Manager - Adapted for FastAPI backend
Handles fetching ROM lists from Myrient and other sources, with caching, filtering, and downloading.
"""
import os
import re
import logging
import zipfile
from urllib.parse import unquote, quote
from typing import List, Dict, Optional, Callable

import requests
from bs4 import BeautifulSoup
import py7zr

from .config_manager import ConfigManager

logger = logging.getLogger(__name__)


class RomManager:
    def __init__(self, config_manager: ConfigManager):
        self.config = config_manager
        self.consoles = self.config.consoles
        self.cache: Dict[str, List[Dict]] = {}  # {console_key: [list of files]}
        
        # Default filter settings
        self.filters = {
            "regions": ["Europe", "France", "Fr", "USA", "Japan"],
            "exclude": ["Demo", "Beta", "Proto", "Kiosk", "Sample", "Unl"],
            "deduplicate": True
        }

    def set_filters(self, regions: List[str] = None, exclude: List[str] = None, deduplicate: bool = None):
        """Update filter settings."""
        if regions is not None:
            self.filters["regions"] = regions
        if exclude is not None:
            self.filters["exclude"] = exclude
        if deduplicate is not None:
            self.filters["deduplicate"] = deduplicate

    def fetch_file_list(self, category: str, console_key: str, force_reload: bool = False) -> List[Dict]:
        """Fetches file list from URL, with caching."""
        cache_key = f"{category}_{console_key}"
        if not force_reload and cache_key in self.cache:
            return self.cache[cache_key]

        try:
            config = self.consoles.get(category, {}).get(console_key)
            if not config:
                logger.warning(f"Console not found: {category}/{console_key}")
                return []
            
            url = config['url']
            exts = tuple(config['exts'])
            
            logger.info(f"Fetching ROM list from {url}")
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            
            soup = BeautifulSoup(response.text, 'html.parser')
            links = []
            
            for link in soup.find_all('a'):
                href = link.get('href')
                if href and href.endswith(exts):
                    filename = unquote(href)
                    if filename not in [".", ".."]:
                        size = self._extract_size(link)
                        links.append({"name": filename, "size": size})
            
            self.cache[cache_key] = links
            logger.info(f"Found {len(links)} files for {console_key}")
            return links
            
        except Exception as e:
            logger.error(f"Error fetching {console_key}: {e}")
            return []

    def _extract_size(self, link_element) -> str:
        """Extract file size from page HTML near the link element."""
        size = "N/A"
        
        # Strategy 1: Table based (Myrient often uses tables)
        parent_td = link_element.find_parent('td')
        if parent_td:
            next_tds = parent_td.find_next_siblings('td')
            for td in next_tds:
                text = td.get_text(strip=True)
                if re.search(r'\d+(\.\d+)?\s*[BKMG]i?B?', text, re.IGNORECASE):
                    size = text
                    break
        
        # Strategy 2: Text based (Apache/Nginx standard directory listing)
        if size == "N/A":
            next_text = link_element.next_sibling
            if next_text and isinstance(next_text, str):
                parts = next_text.strip().split()
                if parts:
                    candidate = parts[-1]
                    if re.match(r'^[\d\.]+[BKMG]$', candidate):
                        size = candidate
        
        return size

    def search(self, category: str, console_key: str, query: str = "", 
               regions: List[str] = None, hide_demos: bool = True, 
               hide_betas: bool = True, deduplicate: bool = True) -> List[Dict]:
        """Search and filter ROM list for a console."""
        files = self.fetch_file_list(category, console_key)
        
        # Use provided filters or defaults
        active_regions = regions if regions else self.filters["regions"]
        exclude_patterns = []
        if hide_demos:
            exclude_patterns.extend(["Demo", "Sample"])
        if hide_betas:
            exclude_patterns.extend(["Beta", "Proto", "Kiosk", "Unl"])
        
        filtered = []
        for item in files:
            f = item["name"]
            
            # 1. Query Filter
            if query and query.lower() not in f.lower():
                continue
            
            # 2. Exclude Filter
            is_excluded = False
            for ex in exclude_patterns:
                if ex.lower() in f.lower():
                    is_excluded = True
                    break
            if is_excluded:
                continue

            # 3. Region Filter (if regions specified)
            if active_regions:
                is_region_match = False
                file_tags = []
                param_groups = re.findall(r'\(([^)]+)\)', f)
                for group in param_groups:
                    parts = [p.strip().lower() for p in group.split(',')]
                    file_tags.extend(parts)
                
                for r in active_regions:
                    clean_r = r.lower()
                    if clean_r in file_tags:
                        is_region_match = True
                        break
                    
                if not is_region_match:
                    continue
            
            filtered.append(item)

        # 4. Deduplicate
        if deduplicate:
            filtered = self._deduplicate(filtered)
            
        return filtered

    def _deduplicate(self, file_list: List[Dict]) -> List[Dict]:
        """Deduplicate list keeping best revisions."""
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

    def _get_base_title(self, filename: str) -> str:
        """Extract base game title without version/region tags."""
        name = os.path.splitext(filename)[0]
        def replace_params(match):
            c = match.group(0).lower()
            if "disc" in c or "disk" in c:
                return c
            return ""
        return re.sub(r'\s*\([^)]+\)', replace_params, name).strip()

    def _get_score(self, filename: str) -> int:
        """Score a ROM file for deduplication priority."""
        score = 0
        if "(France)" in filename or "(Fr)" in filename:
            score += 2
        elif "(Europe)" in filename:
            score += 1
        if "Virtual Console" in filename:
            score -= 50
        return score

    def download_file(self, category: str, console_key: str, filename: str, 
                      progress_callback: Optional[Callable] = None) -> bool:
        """Download a single ROM file."""
        try:
            config = self.consoles[category][console_key]
            base_url = config['url']
            
            # Build download URL
            if "myrient" in base_url or "archive.org" in base_url:
                if not base_url.endswith("/"):
                    base_url += "/"
                download_url = base_url + quote(filename)
            else:
                download_url = base_url + filename
            
            # Build save path
            folder_name = config.get('folder', console_key)
            root_path = self.config.get_download_path()
            save_dir = os.path.join(root_path, folder_name)
            
            os.makedirs(save_dir, exist_ok=True)
            filepath = os.path.join(save_dir, filename)
            
            # Skip if already exists
            if os.path.exists(filepath):
                logger.info(f"File already exists: {filename}")
                if progress_callback:
                    progress_callback(1.0, "Exists")
                return True

            logger.info(f"Downloading: {download_url}")
            response = requests.get(download_url, stream=True, timeout=60)
            response.raise_for_status()
            
            total = int(response.headers.get('content-length', 0))
            downloaded = 0
            
            # Download to temp file first
            with open(filepath + ".tmp", 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    if chunk:
                        f.write(chunk)
                        downloaded += len(chunk)
                        if progress_callback and total > 0:
                            progress_callback(downloaded / total, f"{downloaded/1024/1024:.1f} MB")
            
            # Rename to final filename
            os.replace(filepath + ".tmp", filepath)
            
            # Extract if archive
            if filename.endswith((".zip", ".7z")):
                self._extract(filepath)
                
            if progress_callback:
                progress_callback(1.0, "Done")
            
            logger.info(f"Downloaded successfully: {filename}")
            return True
            
        except Exception as e:
            logger.error(f"Download error for {filename}: {e}")
            if progress_callback:
                progress_callback(0, f"Error: {e}")
            return False

    def _extract(self, filepath: str):
        """Extract archive and remove original file."""
        try:
            directory = os.path.dirname(filepath)
            if filepath.endswith(".zip"):
                with zipfile.ZipFile(filepath, 'r') as z:
                    z.extractall(directory)
            elif filepath.endswith(".7z"):
                with py7zr.SevenZipFile(filepath, 'r') as z:
                    z.extractall(directory)
            os.remove(filepath)
            logger.info(f"Extracted and removed: {filepath}")
        except Exception as e:
            logger.error(f"Extraction error for {filepath}: {e}")

    def get_console_info(self, category: str, console_key: str) -> Optional[Dict]:
        """Get console configuration."""
        return self.consoles.get(category, {}).get(console_key)

    def get_all_consoles(self) -> Dict:
        """Get full console catalog."""
        return self.consoles
