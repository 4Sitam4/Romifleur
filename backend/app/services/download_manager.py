"""
Download Manager - Adapted for FastAPI backend
Handles download queue and parallel downloads with progress tracking.
"""
import threading
import concurrent.futures
import logging
import asyncio
from typing import List, Tuple, Optional, Callable, Dict, Any

from .rom_manager import RomManager

logger = logging.getLogger(__name__)


class DownloadManager:
    def __init__(self, rom_manager: RomManager):
        self.rom_manager = rom_manager
        self.queue: List[Tuple[str, str, str, str]] = []  # List of (Category, Console, Filename, Size)
        self.is_downloading = False
        self.lock = threading.Lock()
        
        # Progress tracking for API
        self.current_progress = 0.0
        self.current_status = ""
        self.completed_count = 0
        self.total_count = 0
        self.current_file = ""
        
        # WebSocket connections for progress updates
        self.progress_callbacks: List[Callable] = []

    def add_to_queue(self, category: str, console: str, filename: str, size: str = "N/A") -> bool:
        """Add item to download queue. Returns False if duplicate."""
        with self.lock:
            # Check for duplicates
            for item in self.queue:
                if item[2] == filename:
                    logger.debug(f"Duplicate in queue: {filename}")
                    return False
            
            self.queue.append((category, console, filename, size))
            logger.info(f"Added to queue: {filename} ({size})")
            return True

    def add_batch_to_queue(self, items: List[Dict[str, str]]) -> int:
        """Add multiple items to queue. Returns count of items added."""
        added = 0
        for item in items:
            if self.add_to_queue(
                item.get("category", ""),
                item.get("console", ""),
                item.get("filename", ""),
                item.get("size", "N/A")
            ):
                added += 1
        return added

    def remove_from_queue(self, index: int) -> bool:
        """Remove item from queue by index."""
        with self.lock:
            if 0 <= index < len(self.queue):
                removed = self.queue.pop(index)
                logger.info(f"Removed from queue: {removed[2]}")
                return True
            return False

    def clear_queue(self):
        """Clear entire download queue."""
        with self.lock:
            count = len(self.queue)
            self.queue = []
            logger.info(f"Cleared {count} items from queue")

    def get_queue(self) -> List[Dict[str, str]]:
        """Get queue as list of dicts for API response."""
        with self.lock:
            return [
                {
                    "category": item[0],
                    "console": item[1],
                    "filename": item[2],
                    "size": item[3]
                }
                for item in self.queue
            ]

    def get_queue_count(self) -> int:
        """Get number of items in queue."""
        return len(self.queue)

    def get_progress(self) -> Dict[str, Any]:
        """Get current download progress."""
        return {
            "current": self.completed_count,
            "total": self.total_count,
            "percentage": self.current_progress,
            "status": self.current_status,
            "current_file": self.current_file,
            "is_downloading": self.is_downloading
        }

    def register_progress_callback(self, callback: Callable):
        """Register a callback for progress updates (for WebSocket)."""
        self.progress_callbacks.append(callback)

    def unregister_progress_callback(self, callback: Callable):
        """Unregister a progress callback."""
        if callback in self.progress_callbacks:
            self.progress_callbacks.remove(callback)

    def _notify_progress(self):
        """Notify all registered callbacks of progress update."""
        progress_data = self.get_progress()
        for callback in self.progress_callbacks:
            try:
                callback(progress_data)
            except Exception as e:
                logger.error(f"Progress callback error: {e}")

    def start_download(self, progress_callback: Optional[Callable] = None, 
                       completion_callback: Optional[Callable] = None) -> bool:
        """Start downloading queue. Returns False if already downloading or queue empty."""
        if not self.queue or self.is_downloading:
            return False

        self.is_downloading = True
        self.completed_count = 0
        self.total_count = len(self.queue)
        self.current_progress = 0.0
        self.current_status = "Starting downloads..."
        
        logger.info(f"Starting download batch of {self.total_count} files")
        
        # Run in a separate thread to not block API
        thread = threading.Thread(
            target=self._worker, 
            args=(list(self.queue), progress_callback, completion_callback)
        )
        thread.daemon = True
        thread.start()
        return True

    def _worker(self, queue_items: List[Tuple], progress_callback: Optional[Callable], 
                completion_callback: Optional[Callable]):
        """Background worker for parallel downloads."""
        total = len(queue_items)
        max_workers = 3
        
        def update_overall_progress(file_done: bool = False, current_file: str = ""):
            with self.lock:
                if file_done:
                    self.completed_count += 1
                
                if current_file:
                    self.current_file = current_file
                
                self.current_progress = self.completed_count / total if total > 0 else 0
                self.current_status = f"Downloading... [{self.completed_count}/{total}]"
                
                if progress_callback:
                    progress_callback(self.current_progress, self.current_status)
                
                self._notify_progress()

        def download_task(item: Tuple) -> bool:
            cat, console, fname, _ = item
            update_overall_progress(current_file=fname)
            
            success = self.rom_manager.download_file(cat, console, fname)
            if success:
                logger.info(f"Successfully downloaded: {fname}")
            else:
                logger.error(f"Failed to download: {fname}")
            
            update_overall_progress(file_done=True)
            return success
        
        # Parallel download
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = [executor.submit(download_task, item) for item in queue_items]
            concurrent.futures.wait(futures)
        
        # Clear queue after download
        with self.lock:
            self.queue = []
        
        self.is_downloading = False
        self.current_status = "Download complete!"
        self.current_file = ""
        self._notify_progress()
        
        logger.info("Download batch complete")
        if completion_callback:
            completion_callback()
