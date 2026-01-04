import customtkinter as ctk
import tkinter as tk
from tkinter import ttk
import threading
import os
import platform
import subprocess
from rom_manager import RomManager

ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("blue")

class App(ctk.CTk):
    def __init__(self):
        super().__init__()
        
        self.title("Romifleur - Ultimate ROM Downloader")
        self.geometry("1300x700") # Wider for Queue
        
        self.manager = RomManager()
        self.selected_category = None
        self.selected_console = None
        self.download_queue = [] # List of (Category, Console, Filename)
        
        self._setup_ui()
        
    def _setup_ui(self):
        # Layout: grid 1 row, 3 cols (Sidebar, Main, Queue)
        self.grid_columnconfigure(1, weight=1)
        self.grid_rowconfigure(0, weight=1)
        
        # --- Left Sidebar (Consoles) ---
        self.sidebar = ctk.CTkFrame(self, width=200, corner_radius=0)
        self.sidebar.grid(row=0, column=0, sticky="nsew")
        
        from PIL import Image
        
        # Logo Setup
        try:
            base_path = os.path.dirname(__file__)
            
            # 1. Main Logo (Sidebar)
            # Try specific filenames
            main_logo_path = os.path.join(base_path, "logo-romifleur.png")
            if not os.path.exists(main_logo_path):
                 main_logo_path = os.path.join(base_path, "Romifleur_logo.png")
            
            if os.path.exists(main_logo_path):
                pil_image = Image.open(main_logo_path)
                self.logo_image = ctk.CTkImage(light_image=pil_image, dark_image=pil_image, size=(180, 180))
                self.logo_label = ctk.CTkLabel(self.sidebar, text="", image=self.logo_image)
            else:
                self.logo_label = ctk.CTkLabel(self.sidebar, text="Romifleur", font=ctk.CTkFont(size=20, weight="bold"))
            
            # 2. Window Icon (Taskbar/Mini)
            mini_logo_path = os.path.join(base_path, "logo-romifleur-mini.png")
            if os.path.exists(mini_logo_path):
                from PIL import ImageTk
                icon_image = Image.open(mini_logo_path)
                self.icon_photo = ImageTk.PhotoImage(icon_image)
                self.wm_iconphoto(False, self.icon_photo)
            
        except Exception as e:
            print(f"Error loading logos: {e}")
            if not hasattr(self, 'logo_label'):
                self.logo_label = ctk.CTkLabel(self.sidebar, text="Romifleur", font=ctk.CTkFont(size=20, weight="bold"))
                
        self.logo_label.pack(padx=20, pady=20)
        
        # Open Folder Button
        self.open_folder_btn = ctk.CTkButton(self.sidebar, text="Open ROMs Folder", fg_color="#555", command=self._open_roms_folder)
        self.open_folder_btn.pack(padx=20, pady=(0, 10))

        # Settings Button
        self.settings_btn = ctk.CTkButton(self.sidebar, text="Settings ⚙️", fg_color="#444", command=self._open_settings)
        self.settings_btn.pack(padx=20, pady=(0, 20))
        
        # Scrollable list for consoles
        self.console_list_frame = ctk.CTkScrollableFrame(self.sidebar, label_text="Consoles")
        self.console_list_frame.pack(fill="both", expand=True, padx=10, pady=10)
        
        self._populate_console_list()
        
        # --- Middle Area (Game List) ---
        self.main_frame = ctk.CTkFrame(self, corner_radius=0)
        self.main_frame.grid(row=0, column=1, sticky="nsew")
        self.main_frame.grid_rowconfigure(2, weight=1) 
        self.main_frame.grid_columnconfigure(0, weight=1)
        
        # Header
        self.header_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.header_frame.grid(row=0, column=0, sticky="ew", padx=20, pady=10)
        
        self.search_var = tk.StringVar()
        self.search_var.trace("w", self._on_search_change)
        self.search_entry = ctk.CTkEntry(self.header_frame, placeholder_text="Search games...", textvariable=self.search_var, width=300)
        self.search_entry.pack(side="left", padx=(0, 10))
        
        # Region Dropdown
        self.region_var = ctk.StringVar(value="Europe")
        self.region_option = ctk.CTkOptionMenu(self.header_frame, values=["All Regions", "Europe", "USA", "Japan"], 
                                             command=self._refresh_list, variable=self.region_var, width=120)
        self.region_option.pack(side="left", padx=10)

        self.exclude_switch = ctk.CTkSwitch(self.header_frame, text="No Demo/Beta", command=self._refresh_list)
        self.exclude_switch.select()
        self.exclude_switch.pack(side="left", padx=10)
        
        # Info Label
        self.info_label = ctk.CTkLabel(self.main_frame, text="Select a console to begin", font=ctk.CTkFont(size=16))
        self.info_label.grid(row=1, column=0, sticky="w", padx=20, pady=(0, 10))

        # Game List Treeview
        self.tree_frame = ctk.CTkFrame(self.main_frame)
        self.tree_frame.grid(row=2, column=0, sticky="nsew", padx=20, pady=(0, 20))
        self.tree_frame.grid_columnconfigure(0, weight=1)
        self.tree_frame.grid_rowconfigure(0, weight=1)
        
        self.style = ttk.Style()
        self.style.theme_use("clam")
        self.style.configure("Treeview", background="#2b2b2b", fieldbackground="#2b2b2b", foreground="white", borderwidth=0)
        self.style.configure("Treeview.Heading", background="#1f1f1f", foreground="white", relief="flat")
        self.style.map("Treeview", background=[('selected', '#1f538d')])
        
        # Add "Select" column for checkboxes
        self.tree = ttk.Treeview(self.tree_frame, columns=("Select", "Name", "Status"), show="headings", selectmode="extended")
        self.tree.heading("Select", text="[x]")
        self.tree.heading("Name", text="Game Title")
        self.tree.heading("Status", text="Status")
        
        self.tree.column("Select", width=40, anchor="center")
        self.tree.column("Name", width=400)
        self.tree.column("Status", width=100, anchor="center")
        
        self.tree.grid(row=0, column=0, sticky="nsew")
        self.tree.bind("<Button-1>", self._on_tree_click) # Bind click for checkboxes
        
        self.scrollbar = ttk.Scrollbar(self.tree_frame, orient="vertical", command=self.tree.yview)
        self.scrollbar.grid(row=0, column=1, sticky="ns")
        self.tree.configure(yscrollcommand=self.scrollbar.set)
        
        # Actions Frame (Middle)
        self.action_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        self.action_frame.grid(row=3, column=0, sticky="ew", padx=20, pady=20)
        
        # Replaced "Download Selected" with "Add to queue"
        self.add_queue_btn = ctk.CTkButton(self.action_frame, text="Add to Queue ➡️", command=self._add_to_queue)
        self.add_queue_btn.pack(side="right")

        self.select_all_btn = ctk.CTkButton(self.action_frame, text="Select All", command=self._select_all_toggle, width=100, fg_color="#444")
        self.select_all_btn.pack(side="right", padx=10)
        
        self.best_btn = ctk.CTkButton(self.action_frame, text="Load Best Games", fg_color="green", command=self._load_best_games)
        self.best_btn.pack(side="left", padx=10)

        # --- Right Sidebar (Queue) ---
        self.queue_sidebar = ctk.CTkFrame(self, width=300, corner_radius=0)
        self.queue_sidebar.grid(row=0, column=2, sticky="nsew")
        self.queue_sidebar.grid_rowconfigure(1, weight=1)
        
        self.queue_label = ctk.CTkLabel(self.queue_sidebar, text="Download Queue", font=ctk.CTkFont(size=18, weight="bold"))
        self.queue_label.pack(padx=20, pady=20)
        
        self.queue_list_frame = ctk.CTkScrollableFrame(self.queue_sidebar, label_text="Pending Items")
        self.queue_list_frame.pack(fill="both", expand=True, padx=10, pady=(0, 10))
        
        self.queue_status_label = ctk.CTkLabel(self.queue_sidebar, text="0 items")
        self.queue_status_label.pack(pady=5)
        
        self.start_download_btn = ctk.CTkButton(self.queue_sidebar, text="Start Downloads 🚀", fg_color="#E0a500", text_color="black", command=self._start_queue_download)
        self.start_download_btn.pack(padx=20, pady=10, fill="x")
        
        # Queue Actions (Import/Export)
        self.queue_actions_frame = ctk.CTkFrame(self.queue_sidebar, fg_color="transparent")
        self.queue_actions_frame.pack(padx=20, pady=(0, 20), fill="x")
        
        self.export_btn = ctk.CTkButton(self.queue_actions_frame, text="Save List 💾", width=80, fg_color="#555", command=self._export_queue)
        self.export_btn.pack(side="left", padx=(0, 5), expand=True, fill="x")
        
        self.import_btn = ctk.CTkButton(self.queue_actions_frame, text="Load 📂", width=80, fg_color="#555", command=self._import_queue)
        self.import_btn.pack(side="left", padx=(5, 0), expand=True, fill="x")
        
        self.clear_btn = ctk.CTkButton(self.queue_sidebar, text="Clear All 🗑️", fg_color="#AA0000", command=self._clear_queue)
        self.clear_btn.pack(padx=20, pady=(10, 20), fill="x")
        
        self.progress_bar = ctk.CTkProgressBar(self.queue_sidebar, orientation="horizontal")
        self.progress_bar.set(0)
        self.progress_bar.pack(padx=20, pady=(0, 20), fill="x")
        self.progress_bar.pack_forget()

    def _clear_queue(self):
        self.download_queue = []
        self._update_queue_ui()
        self.info_label.configure(text="Queue cleared.")

    def _remove_from_queue(self, index):
        if 0 <= index < len(self.download_queue):
            del self.download_queue[index]
            self._update_queue_ui()

    def _update_queue_ui(self):
        # Clear frame
        for widget in self.queue_list_frame.winfo_children():
            widget.destroy()
            
        for i, (cat, console, filename) in enumerate(self.download_queue):
            # Container
            item_frame = ctk.CTkFrame(self.queue_list_frame, fg_color="transparent")
            item_frame.pack(fill="x", pady=2)
            
            # Remove Button
            remove_btn = ctk.CTkButton(item_frame, text="❌", width=30, height=20, fg_color="darkred", 
                                       command=lambda idx=i: self._remove_from_queue(idx))
            remove_btn.pack(side="right", padx=(5, 0))
            
            # Label
            # Get clean name for display
            display_name = filename[:22] + "..." if len(filename) > 22 else filename
            lbl = ctk.CTkLabel(item_frame, text=f"[{console}] {display_name}", anchor="w", height=20)
            lbl.pack(side="left", fill="x", expand=True)
            
        self.queue_status_label.configure(text=f"{len(self.download_queue)} items in queue")

    def _export_queue(self):
        import json
        from tkinter import filedialog
        
        if not self.download_queue: return
        
        filename = filedialog.asksaveasfilename(defaultextension=".json", filetypes=[("JSON Files", "*.json")])
        if not filename: return
        
        try:
            with open(filename, 'w') as f:
                json.dump(self.download_queue, f, indent=4)
            self.info_label.configure(text=f"Queue saved to {os.path.basename(filename)}")
        except Exception as e:
            self.info_label.configure(text=f"Error saving: {e}")

    def _import_queue(self):
        import json
        from tkinter import filedialog
        
        filename = filedialog.askopenfilename(filetypes=[("JSON Files", "*.json")])
        if not filename: return
        
        try:
            with open(filename, 'r') as f:
                data = json.load(f)
                
            # Basic validation
            if isinstance(data, list):
                count = 0
                for item in data:
                    # Expect [cat, console, filename]
                    if isinstance(item, list) and len(item) == 3:
                        # Check duplicates
                        if not any(x[2] == item[2] for x in self.download_queue):
                            self.download_queue.append(tuple(item))
                            count += 1
                
                self._update_queue_ui()
                self.info_label.configure(text=f"Imported {count} items.")
        except Exception as e:
            self.info_label.configure(text=f"Error importing: {e}")

    def _open_settings(self):
        # Allow user to pick download folder
        from tkinter import filedialog
        current = self.manager.settings.get("roms_path", "ROMs")
        
        path = filedialog.askdirectory(initialdir=current, title="Select ROMs Destination Folder")
        if path:
            self.manager.settings["roms_path"] = path
            self.manager.save_settings()
            self.info_label.configure(text=f"Download path set to: {path}")

    def _populate_console_list(self):
        # Clear existing
        for widget in self.console_list_frame.winfo_children():
            widget.destroy()

        self.category_frames = {} # {category_name: frame}
        self.category_buttons = {} # {category_name: (button, arrow_label)}

        # Iterate over categories in alphabetical order or specific order
        for category, consoles_data in self.manager.consoles.items():
            self._create_category_group(category, consoles_data)

    def _create_category_group(self, category, consoles_data):
        # Create a parent frame for this entire group (Header + Content)
        # This ensures they stay together in the main list order
        group_frame = ctk.CTkFrame(self.console_list_frame, fg_color="transparent")
        group_frame.pack(fill="x", pady=2)

        # 1. Category Header Button
        header_frame = ctk.CTkFrame(group_frame, fg_color="transparent")
        header_frame.pack(fill="x", pady=0)
        
        # Using a button for the whole header
        is_expanded = True
        
        # Container for content (initially visible)
        content_frame = ctk.CTkFrame(group_frame, fg_color="transparent")
        content_frame.pack(fill="x", padx=10, pady=0)
        
        # Toggle function
        def toggle_category(cat=category):
            frame = self.category_frames[cat]
            btn = self.category_buttons[cat]
            if frame.winfo_viewable():
                frame.pack_forget()
                btn.configure(text=f"▶ {cat}")
            else:
                frame.pack(fill="x", padx=10, pady=0)
                btn.configure(text=f"▼ {cat}")

        btn = ctk.CTkButton(header_frame, text=f"▼ {category}", fg_color="#333", hover_color="#444", 
                            anchor="w", command=toggle_category, font=("Arial", 13, "bold"))
        btn.pack(fill="x")
        
        self.category_frames[category] = content_frame
        self.category_buttons[category] = btn

        # 2. Console Buttons inside content_frame
        # Sort consoles by name inside category
        sorted_keys = sorted(consoles_data.keys(), key=lambda k: consoles_data[k]['name'])
        
        for key in sorted_keys:
            data = consoles_data[key]
            name = data['name']
            
            # Simple button
            c_btn = ctk.CTkButton(content_frame, text=name, anchor="w", fg_color="transparent", 
                                  hover_color="#3A3A3A", height=24,
                                  command=lambda c=category, k=key: self._on_console_select(c, k))
            c_btn.pack(fill="x", pady=1)

    def _on_console_select(self, category, key):
        self.selected_category = category
        self.selected_console = key
        name = self.manager.consoles[category][key]['name']
        self.info_label.configure(text=f"Loading {name}...")
        self.update()
        threading.Thread(target=self._fetch_and_show, args=(category, key, name)).start()

    def _fetch_and_show(self, category, key, name):
        self.manager.fetch_file_list(category, key)
        self.after(0, lambda: self._update_view_after_load(name))

    def _update_view_after_load(self, name):
        self.info_label.configure(text=f"{name} - {len(self.manager.cache.get(f'{self.selected_category}_{self.selected_console}', []))} files found")
        self._refresh_list()

    def _refresh_list(self, *args):
        if not self.selected_console: return
        region_map = {
            "Europe": ["(Europe)", "(France)", "(Fr)", "(Germany)", "(De)", "(Spain)", "(Es)", "(Italy)", "(It)"],
            "USA": ["(USA)", "(US)"],
            "Japan": ["(Japan)", "(JP)", "(In)"],
            "All Regions": []
        }
        selected_region = self.region_var.get()
        self.manager.filters["region"] = region_map.get(selected_region, [])
        self.manager.filters["exclude"] = ["(Demo)", "(Beta)", "(Proto)", "(Kiosk)", "(Sample)", "(Unl)"] if self.exclude_switch.get() else []
        self.manager.filters["deduplicate"] = True 
        
        query = self.search_var.get()
        results = self.manager.search(self.selected_category, self.selected_console, query)
        
        self.tree.delete(*self.tree.get_children())
        for r in results:
            self.tree.insert("", "end", values=("☐", r, "Online"))

    def _on_tree_click(self, event):
        region = self.tree.identify("region", event.x, event.y)
        if region == "cell":
            column = self.tree.identify_column(event.x)
            if column == "#1": 
                item_id = self.tree.identify_row(event.y)
                current_values = self.tree.item(item_id, "values")
                if current_values:
                    new_val = "☑" if current_values[0] == "☐" else "☐"
                    self.tree.item(item_id, values=(new_val, current_values[1], current_values[2]))
                    return "break"

    def _select_all_toggle(self):
        children = self.tree.get_children()
        if not children: return
        first_val = self.tree.item(children[0], "values")[0]
        new_val = "☑" if first_val == "☐" else "☐"
        for item in children:
            vals = self.tree.item(item, "values")
            self.tree.item(item, values=(new_val, vals[1], vals[2]))

    def _on_search_change(self, *args):
        self._refresh_list()
        
    def _load_best_games(self):
        if not self.selected_console: return
        config = self.manager.consoles.get(self.selected_category, {}).get(self.selected_console, {})
        best = config.get("best_games", [])
        
        self.tree.delete(*self.tree.get_children())
        
        # Get all available files
        available = self.manager.cache.get(f"{self.selected_category}_{self.selected_console}", [])
        
        # We need to filter 'available' by current filters first (Region, Exclude)
        # using the manager's search logic slightly adapted or just manual filtering here.
        # Let's filter available list first using strict filters to remove unwanted regions/demos
        filtered_available = []
        region_filter = self.manager.filters.get("region", [])
        exclude_filter = self.manager.filters.get("exclude", [])
        
        for f in available:
            # Exclude
            if any(ex.lower() in f.lower() for ex in exclude_filter): continue
            
            # Region (Strict if set)
            if region_filter:
                if not any(r.lower() in f.lower() for r in region_filter): continue
            
            filtered_available.append(f)

        # Now search for best games in filtered list
        for bg in best:
            matches = []
            for av in filtered_available:
                # Check containment. 
                # Be careful: "Metroid" matches "Metroid Fusion" and "Super Metroid".
                # We want robust matching. 
                # A simple heuristic: av name must contain bg name.
                # And to avoid "Metroid" matching "Super Metroid", maybe check word start?
                # For now simple containment is used but let's score them.
                if bg.lower() in av.lower():
                    score = self.manager._get_score(av)
                    matches.append((score, av))
            
            if matches:
                # Deduplicate: Pick the HIGHEST score.
                matches.sort(key=lambda x: x[0], reverse=True)
                best_match = matches[0][1]
                
                # Check if we already added it (prevent duplicates if multiple best games match same file)
                # Not easy to check tree efficiently, but list is small.
                exists = False
                for child in self.tree.get_children():
                    if self.tree.item(child)["values"][1] == best_match:
                        exists = True
                        break
                
                if not exists:
                     self.tree.insert("", "end", values=("☐", best_match, "Best Of"))

    # --- New Queue Methods ---

    def _open_roms_folder(self):
        path = self.manager.get_download_path()
        if not os.path.exists(path):
            try:
                os.makedirs(path)
            except:
                pass
        
        if platform.system() == "Windows":
            os.startfile(path)
        elif platform.system() == "Darwin":
            subprocess.Popen(["open", path])
        else:
            subprocess.Popen(["xdg-open", path])

    def _add_to_queue(self):
        # Identify selected Items
        checked_items = []
        for item in self.tree.get_children():
            vals = self.tree.item(item, "values")
            if vals[0] == "☑":
                checked_items.append(vals[1])
        
        if not checked_items:
            selected_items = self.tree.selection()
            if selected_items:
               checked_items = [self.tree.item(i)['values'][1] for i in selected_items]
        
        if not checked_items: return
    
        # Add to global queue
        count = 0
        for filename in checked_items:
            # Check if already in queue
            if not any(x[2] == filename for x in self.download_queue):
                self.download_queue.append((self.selected_category, self.selected_console, filename))
                count += 1
                
        self._update_queue_ui()
        self.info_label.configure(text=f"Added {count} items to queue.")

    def _start_queue_download(self):
        if not self.download_queue: return
        
        self.start_download_btn.configure(state="disabled", text="Downloading...")
        self.progress_bar.pack(padx=20, pady=(0, 20), fill="x")
        self.progress_bar.set(0)
        
        # Clone queue for worker
        queue_copy = list(self.download_queue)
        threading.Thread(target=self._queue_worker, args=(queue_copy,)).start()

    def _queue_worker(self, queue_items):
        import concurrent.futures
        
        total = len(queue_items)
        completed = 0
        max_workers = 3 
        
        lock = threading.Lock()
        
        def update_overall_progress(file_done):
            nonlocal completed
            with lock:
                if file_done:
                    completed += 1
                prog = completed / total
                status = f"Downloading... [{completed}/{total}]"
                self.after(0, lambda p=prog, s=status: self._update_queue_progress(p, s))

        def download_task(item):
            cat, console, fname = item
            self.manager.download_file(cat, console, fname, progress_callback=None)
            update_overall_progress(True)
            
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = [executor.submit(download_task, item) for item in queue_items]
            concurrent.futures.wait(futures)
        
        self.after(0, lambda: self._finish_queue_download())

    def _update_queue_progress(self, progress, status):
        self.progress_bar.set(progress)
        self.queue_status_label.configure(text=status)

    def _finish_queue_download(self):
        self.start_download_btn.configure(state="normal", text="Start Downloads 🚀")
        self.progress_bar.pack_forget()
        self.queue_status_label.configure(text="All Downloads Complete!")
        # Clear queue?
        self.download_queue = []
        self._update_queue_ui()
        self._open_roms_folder() # Auto open folder?
        
if __name__ == "__main__":
    # Fix Taskbar Icon grouping
    try:
        from ctypes import windll
        myappid = 'romifleur.v2.gui'
        windll.shell32.SetCurrentProcessExplicitAppUserModelID(myappid)
    except ImportError:
        pass
        
    app = App()
    app.mainloop()
