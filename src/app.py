
import customtkinter as ctk
from .core.config_manager import ConfigManager
from .core.rom_manager import RomManager
from .core.ra_manager import RetroAchievementsManager
from .core.download_manager import DownloadManager
from .core.metadata_manager import MetadataManager
from .ui.main_window import MainWindow

class App:
    def __init__(self):
        # Initialize Core Services
        self.config = ConfigManager()
        self.rom_manager = RomManager(self.config)
        self.ra_manager = RetroAchievementsManager(self.config)
        self.metadata_manager = MetadataManager(self.config, self.ra_manager)
        self.download_manager = DownloadManager(self.rom_manager)
        
        # Setup Global Appearance
        ctk.set_appearance_mode("Dark")
        ctk.set_default_color_theme("blue")
        
        # Initialize UI
        self.window = MainWindow(self)

    def run(self):
        self.window.mainloop()
