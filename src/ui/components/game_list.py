import customtkinter as ctk
import tkinter as tk
from tkinter import ttk
import threading
import os
from PIL import Image, ImageTk
from src.utils.path_utils import resource_path

class GameList(ctk.CTkFrame):
    def __init__(self, master, app_context, on_add_queue, **kwargs):
        super().__init__(master, **kwargs)
        self.app = app_context
        self.on_add_queue = on_add_queue
        
        self.current_results = []
        self.selected_files = set()
        self.selected_files = set()
        self.showing_best = False
        self.ra_sort_desc = True # Default sort order for RA
        
        self._load_icons()
        
        self._load_icons()
        self._setup_ui()

    def _load_icons(self):
        assets_dir = resource_path("assets")
        
        def load_resize(name):
            try:
                path = os.path.join(assets_dir, name)
                img = Image.open(path)
                return ImageTk.PhotoImage(img.resize((20, 20), Image.Resampling.LANCZOS))
            except Exception as e:
                print(f"Error loading icon {name}: {e}")
                return None

        self.img_trophy = load_resize("Trophy_RA.png")
        self.img_cross = load_resize("Cross_RA.png")
        self.img_question = load_resize("QuestionMark_RA.png")

    def _setup_ui(self):
        self.grid_rowconfigure(2, weight=1)
        self.grid_columnconfigure(0, weight=1)
        
        # Configure ttk Styles (doing it here to ensure it applies before widget creation if needed, 
        # though theme_use updates existing ones)
        style = ttk.Style()
        style.theme_use("clam")
        
        # Combobox: Flat, Dark, White Arrow
        # We must configure the distinct elements for Clam theme to remove the 3D button feel
        style.configure("TCombobox", 
                        fieldbackground="#343638", 
                        background="#343638", 
                        foreground="white", 
                        arrowcolor="white",
                        darkcolor="#343638", # Removes 3D border shadow
                        lightcolor="#343638", # Removes 3D border highlight
                        selectbackground="#343638",
                        selectforeground="white",
                        borderwidth=0,
                        arrowsize=14)
                        
        style.map("TCombobox", 
                  fieldbackground=[("readonly", "#343638"), ("active", "#343638")], 
                  background=[("readonly", "#343638"), ("active", "#404040"), ("pressed", "#2b2b2b")], 
                  foreground=[("readonly", "white")],
                  arrowcolor=[("readonly", "white")])
                  
        # Dropdown list styling (OptionDB)
        self.master.option_add("*TCombobox*Listbox.background", "#343638")
        self.master.option_add("*TCombobox*Listbox.foreground", "white")
        self.master.option_add("*TCombobox*Listbox.selectBackground", "#1f538d")
        self.master.option_add("*TCombobox*Listbox.selectForeground", "white")
        
        # Header (Filters)
        self.header = ctk.CTkFrame(self, fg_color="transparent")
        self.header.grid(row=0, column=0, sticky="ew", padx=20, pady=10)
        
        self.search_var = tk.StringVar()
        self.search_var.trace("w", self._on_filter_change)
        self.search_entry = ctk.CTkEntry(self.header, placeholder_text="Search games...", textvariable=self.search_var, width=300)
        self.search_entry.pack(side="left", padx=(0, 10))
        
        self.region_var = ctk.StringVar(value="Europe")
        self.region_opt = ttk.Combobox(self.header, values=["All Regions", "Europe", "USA", "Japan"], 
                                         textvariable=self.region_var, width=15, state="readonly")
        self.region_opt.bind("<<ComboboxSelected>>", self._on_filter_change)
        self.region_opt.pack(side="left", padx=10)
        
        self.exclude_switch = ctk.CTkSwitch(self.header, text="No Demo/Beta", command=self._on_filter_change)
        self.exclude_switch.select()
        self.exclude_switch.pack(side="left", padx=10)
        
        self.ra_only_switch = ctk.CTkSwitch(self.header, text="RA Supported Only", command=self._on_filter_change)
        self.ra_only_switch.pack(side="left", padx=10)
        
        # Info Label
        self.info_label = ctk.CTkLabel(self, text="Select a console to begin", font=ctk.CTkFont(size=16))
        self.info_label.grid(row=1, column=0, sticky="w", padx=20, pady=(0, 10))
        
        # Treeview
        self.tree_frame = ctk.CTkFrame(self)
        self.tree_frame.grid(row=2, column=0, sticky="nsew", padx=20, pady=(0, 20))
        self.tree_frame.grid_columnconfigure(0, weight=1)
        self.tree_frame.grid_rowconfigure(0, weight=1)
        
        self._setup_tree()
        
        # Actions
        self.action_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.action_frame.grid(row=3, column=0, sticky="ew", padx=20, pady=20)
        
        self.best_btn = ctk.CTkButton(self.action_frame, text="Load Best Games", fg_color="green", command=self._load_best_games)
        self.best_btn.pack(side="left", padx=10)
        
        self.add_btn = ctk.CTkButton(self.action_frame, text="Add to Queue ➡️", command=self._add_selected)
        self.add_btn.pack(side="right")
        
        ctk.CTkButton(self.action_frame, text="Select All", width=100, fg_color="#444", command=self._toggle_select_all).pack(side="right", padx=10)

    def _setup_tree(self):
        # Scale Treeview for high DPI
        try:
            scaling = ctk.get_window_scaling() if hasattr(ctk, 'get_window_scaling') else 1.0
            if scaling == 1.0 and hasattr(self, '_get_window_scaling'): # fallback
                scaling = self._get_window_scaling()
        except:
             scaling = 1.0

        font_size = int(14 * scaling)
        heading_font_size = int(13 * scaling)
        row_height = int(30 * scaling)
        
        style = ttk.Style()
        style.theme_use("clam")
        style.configure("Treeview", background="#2b2b2b", 
                        fieldbackground="#2b2b2b", 
                        foreground="white", 
                        borderwidth=0, 
                        font=("Arial", font_size),
                        rowheight=row_height)
        
        style.configure("Treeview.Heading", 
                        background="#1f1f1f", 
                        foreground="white", 
                        relief="flat",
                        font=("Arial", heading_font_size, "bold"))
        style.map("Treeview", background=[('selected', '#1f538d')])
        
        # Configure Combobox style to match dark theme
        # Scale column widths
        select_width = int(40 * scaling)
        ra_width = int(40 * scaling)
        size_width = int(80 * scaling)

        self.tree = ttk.Treeview(self.tree_frame, columns=("Select", "Name", "Size"), show="tree headings", selectmode="extended")
        
        self.tree.heading("#0", text="", anchor="center", command=self._sort_by_ra)
        self.tree.column("#0", width=ra_width, stretch=False, anchor="center")
        
        self.tree.heading("Select", text="[x]", anchor="center")
        self.tree.column("Select", width=select_width, stretch=False, anchor="center")
        
        self.tree.heading("Name", text="Game Title", anchor="w")
        self.tree.column("Name", width=450)
        
        self.tree.heading("Size", text="Size", anchor="e")
        self.tree.column("Size", width=size_width, anchor="e")
        
        self.tree.grid(row=0, column=0, sticky="nsew")
        self.scrollbar = ttk.Scrollbar(self.tree_frame, orient="vertical", command=self.tree.yview)
        self.scrollbar.grid(row=0, column=1, sticky="ns")
        self.tree.configure(yscrollcommand=self.scrollbar.set)
        
        self.tree.configure(yscrollcommand=self.scrollbar.set)
        
        self.tree.bind("<Button-1>", self._on_click)
        self.tree.bind("<Double-1>", self._on_double_click)

    def load_console(self, category, console_key):
        self.current_category = category
        self.current_console = console_key
        
        # Reset Best Games state
        self.showing_best = False
        self.best_btn.configure(text="Load Best Games", fg_color="green")
        
        name = self.app.rom_manager.consoles[category][console_key]['name']
        self.info_label.configure(text=f"Loading {name}...")
        
        # Async load
        threading.Thread(target=self._fetch_and_show, args=(category, console_key)).start()

    def _fetch_and_show(self, category, console_key):
        self.app.rom_manager.fetch_file_list(category, console_key)
        self.after(0, self._apply_filters)

    def _on_filter_change(self, *args):
        if hasattr(self, 'current_console'):
            self._apply_filters()

    def _apply_filters(self):
        region_map = {
            "Europe": ["(Europe)", "(France)", "(Fr)", "(Germany)", "(De)", "(Spain)", "(Es)", "(Italy)", "(It)"],
            "USA": ["(USA)", "(US)"],
            "Japan": ["(Japan)", "(JP)", "(In)"],
            "All Regions": []
        }
        
        self.app.rom_manager.filters["region"] = region_map.get(self.region_var.get(), [])
        self.app.rom_manager.filters["exclude"] = ["(Demo)", "(Beta)", "(Proto)", "(Kiosk)", "(Sample)", "(Unl)"] if self.exclude_switch.get() else []
        
        query = self.search_var.get()
        results = self.app.rom_manager.search(self.current_category, self.current_console, query)
        
        # Apply RA Only Filter
        if self.ra_only_switch.get():
            ra_games = self.app.ra_manager.get_supported_games(self.current_console)
            results = [f for f in results if self.app.ra_manager.is_compatible(f, ra_games)]

        self._populate_tree(results)

    def _populate_tree(self, files):
        self.tree.delete(*self.tree.get_children())
        self.current_results = files
        
        # Fetch RA support
        ra_games = self.app.ra_manager.get_supported_games(self.current_console)
        api_key = self.app.ra_manager.api_key
        
        for item in files:
            name = item["name"]
            size = item["size"]
            
            img = self.img_question
            if api_key:
                is_ra = self.app.ra_manager.is_compatible(name, ra_games)
                img = self.img_trophy if is_ra else self.img_cross
            
            self.tree.insert("", "end", text="", image=img, values=("☐", name, size))
            
        self.info_label.configure(text=f"{len(files)} games found")
        self._update_header_icon()

    def _update_header_icon(self):
        api_key = self.app.ra_manager.api_key
        img = self.img_trophy if api_key else self.img_question
        
        # Treeview heading image support depends on theme/style but usually works for #0
        # If text is empty, image centers.
        self.tree.heading("#0", image=img)

    def _on_click(self, event):
        region = self.tree.identify("region", event.x, event.y)
        if region == "cell":
            col = self.tree.identify_column(event.x)
            if col == "#1":
                row_id = self.tree.identify_row(event.y)
                if row_id:
                    vals = self.tree.item(row_id, "values")
                    new_val = "☑" if vals[0] == "☐" else "☐"
                    # Preserve Size if it exists (vals might be len 3 now)
                    if len(vals) > 2:
                        self.tree.item(row_id, values=(new_val, vals[1], vals[2]))
                    else:
                        self.tree.item(row_id, values=(new_val, vals[1]))

    def _on_double_click(self, event):
        row_id = self.tree.identify_row(event.y)
        if row_id:
            vals = self.tree.item(row_id, "values")
            # vals = (checkbox, filename, size)
            filename = vals[1]
            size = vals[2] if len(vals) > 2 else "N/A"
            if self.on_add_queue:
                self.on_add_queue(self.current_category, self.current_console, [(filename, size)])

    def _toggle_select_all(self):
        children = self.tree.get_children()
        if not children: return
        first = self.tree.item(children[0], "values")[0]
        new = "☑" if first == "☐" else "☐"
        for item in children:
            v = self.tree.item(item, "values")
            if len(v) > 2:
                self.tree.item(item, values=(new, v[1], v[2]))
            else:
                self.tree.item(item, values=(new, v[1]))

    def _add_selected(self):
        items = []
        # Check checkboxes
        for item in self.tree.get_children():
            vals = self.tree.item(item, "values")
            if vals[0] == "☑":
                size = vals[2] if len(vals) > 2 else "N/A"
                items.append((vals[1], size))
        
        # Check selection if no checkboxes
        if not items:
            for item in self.tree.selection():
                vals = self.tree.item(item, "values")
                size = vals[2] if len(vals) > 2 else "N/A"
                items.append((vals[1], size))
                
        if items and self.on_add_queue:
            self.on_add_queue(self.current_category, self.current_console, items)

            self.on_add_queue(self.current_category, self.current_console, items)

    def _sort_by_ra(self):
        if not self.current_results: return
        
        # Toggle sort
        self.ra_sort_desc = not self.ra_sort_desc
        
        # Data needed for sort
        ra_games = self.app.ra_manager.get_supported_games(self.current_console)
        
        # Sort logic
        # We sort by (is_compatible, filename)
        # Using a stable sort key
        def sort_key(item):
            filename = item["name"]
            is_ra = self.app.ra_manager.is_compatible(filename, ra_games)
            # Tuple comparison: True > False so (True, name) comes after (False, name) in Ascending
            # If we want Compatible FIRST in Descending:
            return (is_ra, filename.lower())
        
        self.current_results.sort(key=sort_key, reverse=self.ra_sort_desc)
        self._populate_tree(self.current_results)

    def _load_best_games(self):
        # Implementation similar to main logic but simplified helper
        if not hasattr(self, 'current_console'): return
        
        if self.showing_best:
            # Revert to full list (filters applied)
            self._apply_filters()
            self.showing_best = False
            self.best_btn.configure(text="Load Best Games", fg_color="green")
            return

        config = self.app.rom_manager.consoles[self.current_category][self.current_console]
        best_list = config.get("best_games", [])
        
        # We need to filter current results to find matches
        matches = []
        available = self.app.rom_manager.fetch_file_list(self.current_category, self.current_console) # get raw list
        
        # Simple match
        found_set = set()
        for bg in best_list:
            for av in available:
                if bg.lower() in av["name"].lower():
                    # Check if allowed by current filters?
                    # Ideally yes. But "Best Games" usually implies overriding filters?
                    # Let's stick to showing them in the list.
                    if av["name"] not in found_set:
                        matches.append(av)
                        found_set.add(av["name"])
                        break # Find first match for this game? Or all? User might want revisions.
        
        self.search_var.set("") # Clear search
        self._populate_tree(matches)
        
        # Update UI state
        self.showing_best = True
        self.best_btn.configure(text="Back to All Games", fg_color="#444")
