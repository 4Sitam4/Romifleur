
import customtkinter as ctk
import customtkinter as ctk
from tkinter import filedialog, messagebox

class SettingsWindow(ctk.CTkToplevel):
    def __init__(self, master, app_context):
        super().__init__(master)
        self.app = app_context
        self.title("Settings")
        self.geometry("500x400")
        
        self.update_idletasks()
        self.wait_visibility()
        self.grab_set()
        
        self._setup_ui()

    def _setup_ui(self):
        ctk.CTkLabel(self, text="Settings", font=ctk.CTkFont(size=20, weight="bold")).pack(pady=10)
        
        # ROMs Path
        rom_frame = ctk.CTkFrame(self)
        rom_frame.pack(fill="x", padx=20, pady=10)
        
        ctk.CTkLabel(rom_frame, text="ROMs Directory:", anchor="w").pack(fill="x", padx=10, pady=(10, 0))
        
        path_frame = ctk.CTkFrame(rom_frame, fg_color="transparent")
        path_frame.pack(fill="x", padx=10, pady=5)
        
        self.path_entry = ctk.CTkEntry(path_frame)
        self.path_entry.pack(side="left", fill="x", expand=True, padx=(0, 5))
        self.path_entry.insert(0, self.app.config.get_download_path())
        self.path_entry.configure(state="readonly")
        
        ctk.CTkButton(path_frame, text="Browse", width=80, command=self._browse).pack(side="left")
        
        # RA Key
        ra_frame = ctk.CTkFrame(self)
        ra_frame.pack(fill="x", padx=20, pady=10)
        
        ctk.CTkLabel(ra_frame, text="RetroAchievements API Key:", anchor="w").pack(fill="x", padx=10, pady=(10, 0))
        self.ra_entry = ctk.CTkEntry(ra_frame)
        self.ra_entry.pack(fill="x", padx=10, pady=(0, 10))
        self.ra_entry.insert(0, self.app.config.settings.get("ra_api_key", ""))
        


        
        # Save
        ctk.CTkButton(self, text="Save Settings", fg_color="green", command=self._save).pack(pady=20)

    def _browse(self):
        path = filedialog.askdirectory()
        if path:
            self.path_entry.configure(state="normal")
            self.path_entry.delete(0, "end")
            self.path_entry.insert(0, path)
            self.path_entry.configure(state="readonly")

        new_path = self.path_entry.get()
        ra_key = self.ra_entry.get().strip()


        
        # Validation
        if ra_key:
            if not self.app.ra_manager.validate_key(ra_key):
                messagebox.showerror("Invalid API Key", "The RetroAchievements API Key is invalid.\nPlease check it and try again.")
                self.ra_entry.delete(0, "end")
                self.ra_entry.focus()
                return

        self.app.config.settings["roms_path"] = new_path
        self.app.config.settings["ra_api_key"] = ra_key
        # self.app.config.settings["tgdb_api_key"] = tgdb_key # Removed
        self.app.config.save_settings()

        
        # Partial reload?
        # self.app.ra_manager.api_key is a property, so it updates automatically.
        self.destroy()
