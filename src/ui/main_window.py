
import customtkinter as ctk
from .components.sidebar import Sidebar
from .components.game_list import GameList
from .components.queue_panel import QueuePanel
from ..utils.image_utils import ImageUtils

class MainWindow(ctk.CTk):
    def __init__(self, app_context):
        super().__init__()
        self.app = app_context
        
        self.title(f"Romifleur {self._get_version()}")
        self.geometry("1300x700")
        
        # Icon
        ImageUtils.set_window_icon(self, "logo-romifleur-mini.png")
        
        self._setup_layout()
        
    def _get_version(self):
        return "v1.2.0"

    def _setup_layout(self):
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)
        
        # 1. Sidebar (Left)
        self.sidebar = Sidebar(self, self.app, on_console_select=self._on_console_select, width=200, corner_radius=0)
        self.sidebar.grid(row=0, column=0, sticky="nsew")
        
        # 2. Game List (Middle)
        self.game_list = GameList(self, self.app, on_add_queue=self._on_add_to_queue, corner_radius=0)
        self.game_list.grid(row=0, column=1, sticky="nsew")
        
        # 3. Queue (Right)
        self.queue_panel = QueuePanel(self, self.app, width=300, corner_radius=0)
        self.queue_panel.grid(row=0, column=2, sticky="nsew")

    def _on_console_select(self, category, console_key):
        self.game_list.load_console(category, console_key)

    def _on_add_to_queue(self, category, console, items):
        count = self.queue_panel.add_items(category, console, items)
        # Optional: Show ephemeral message or status?
        pass
