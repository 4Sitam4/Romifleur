
import customtkinter as ctk
import os
import json
import platform
import subprocess
from tkinter import filedialog

class QueuePanel(ctk.CTkFrame):
    def __init__(self, master, app_context, **kwargs):
        super().__init__(master, **kwargs)
        self.app = app_context
        self._setup_ui()
        
    def _setup_ui(self):
        self.grid_rowconfigure(1, weight=1)
        
        # Header
        ctk.CTkLabel(self, text="Download Queue", font=ctk.CTkFont(size=18, weight="bold")).pack(padx=20, pady=20)
        
        # Clear Button (Moved here, above list)
        ctk.CTkButton(self, text="Clear All 🗑️", fg_color="#AA0000", command=self._clear).pack(padx=20, pady=(0, 10), fill="x")

        # List
        self.queue_list = ctk.CTkScrollableFrame(self, label_text="Pending Items")
        self.queue_list.pack(fill="both", expand=True, padx=10, pady=(0, 10))
        
        # Fix scroll logic (focus on hover)
        self.queue_list.bind("<Enter>", self._bind_mouse_wheel)
        self.queue_list.bind("<Leave>", self._unbind_mouse_wheel)

        
        self.status_label = ctk.CTkLabel(self, text="0 items")
        self.status_label.pack(pady=5)

        
        # Start Button
        self.start_btn = ctk.CTkButton(self, text="Start Downloads 🚀", fg_color="#E0a500", text_color="black", command=self._start_download)
        self.start_btn.pack(padx=20, pady=10, fill="x")
        
        # I/O Buttons
        io_frame = ctk.CTkFrame(self, fg_color="transparent")
        io_frame.pack(padx=20, pady=(0, 20), fill="x")
        
        ctk.CTkButton(io_frame, text="Save 💾", width=80, fg_color="#555", command=self._export).pack(side="left", padx=(0, 5), expand=True, fill="x")
        ctk.CTkButton(io_frame, text="Load 📂", width=80, fg_color="#555", command=self._import).pack(side="left", padx=(5, 0), expand=True, fill="x")
        
        # Open Folder Button (Moved from Sidebar)
        ctk.CTkButton(self, text="Open ROMs Folder", fg_color="#555", command=self._open_roms_folder).pack(padx=20, pady=(10, 20), fill="x")
        
        # Progress
        self.progress_bar = ctk.CTkProgressBar(self, orientation="horizontal")
        self.progress_bar.set(0)
        # Hidden by default

    def add_items(self, category, console, items):
        count = 0
        for fname, size in items:
            if self.app.download_manager.add_to_queue(category, console, fname, size):
                count += 1
        self._refresh_list()
        return count

    def _refresh_list(self):
        for widget in self.queue_list.winfo_children():
            widget.destroy()
            
        queue = self.app.download_manager.queue
        total_size = self._calculate_total_size(queue)
        self.status_label.configure(text=f"{len(queue)} items (Approx. {total_size})")
        
        for i, (cat, console, fname, size) in enumerate(queue):
            item_frame = ctk.CTkFrame(self.queue_list, fg_color="transparent")
            item_frame.pack(fill="x", pady=2)
            
            # Remove Button
            btn = ctk.CTkButton(item_frame, text="❌", width=30, height=20, fg_color="darkred", 
                                command=lambda idx=i: self._remove(idx))
            btn.pack(side="right", padx=(5, 0))
            
            display = fname[:20] + "..." if len(fname) > 20 else fname
            ctk.CTkLabel(item_frame, text=f"[{console}] {display}", anchor="w", height=20).pack(side="left", fill="x", expand=True)
            ctk.CTkLabel(item_frame, text=size, font=("Arial", 10), text_color="gray").pack(side="left", padx=5)

    def _calculate_total_size(self, queue):
        total_bytes = 0
        for item in queue:
            # item = (cat, console, fname, size)
            size_str = item[3]
            total_bytes += self._parse_size(size_str)
        return self._format_size(total_bytes)

    def _parse_size(self, size_str):
        if not size_str or size_str == "N/A": return 0
        try:
            # Expected "1.2 MB", "800 KB"
            parts = size_str.split()
            if len(parts) < 2: return 0
            val = float(parts[0])
            unit = parts[1].upper()
            
            multipliers = {
                "B": 1, 
                "KB": 1024, "KIB": 1024, "K": 1024,
                "MB": 1024**2, "MIB": 1024**2, "M": 1024**2,
                "GB": 1024**3, "GIB": 1024**3, "G": 1024**3
            }
            # Handle standard suffixes key matching
            mult = 1
            for k, m in multipliers.items():
                if unit.startswith(k):
                    mult = m
                    # prioritize exact matches first usually, but here checking startsWith KB vs K 
                    # dict iteration order matters if keys overlap. KB comes before K.
                    # Let's simple check
                    break 
            
            return int(val * mult)
        except:
            return 0

    def _format_size(self, size_bytes):
        if size_bytes == 0: return "0 B"
        power = 1024
        n = 0
        power_labels = {0 : '', 1: 'KB', 2: 'MB', 3: 'GB', 4: 'TB'}
        while size_bytes > power:
            size_bytes /= power
            n += 1
        return f"{size_bytes:.2f} {power_labels.get(n, '')}"

    def _remove(self, index):
        self.app.download_manager.remove_from_queue(index)
        self._refresh_list()

    def _clear(self):
        self.app.download_manager.clear_queue()
        self._refresh_list()

    def _export(self):
        if not self.app.download_manager.queue: return
        filename = filedialog.asksaveasfilename(defaultextension=".json", filetypes=[("JSON Files", "*.json")])
        if filename:
            with open(filename, 'w') as f:
                json.dump(self.app.download_manager.queue, f, indent=4)

    def _import(self):
        filename = filedialog.askopenfilename(filetypes=[("JSON Files", "*.json")])
        if not filename: return
        try:
            with open(filename, 'r') as f:
                data = json.load(f)
                if isinstance(data, list):
                    for item in data:
                        if len(item) >= 3:
                            # Support old format (len 3) and new (len 4)
                            cat, cons, fn = item[0], item[1], item[2]
                            sz = item[3] if len(item) > 3 else "N/A"
                            self.app.download_manager.add_to_queue(cat, cons, fn, sz)
            self._refresh_list()
        except Exception as e:
            print(f"Import error: {e}")

    def _open_roms_folder(self):
        path = self.app.config.get_download_path()
        if not os.path.exists(path):
            return
            
        if platform.system() == "Windows":
            os.startfile(path)
        elif platform.system() == "Darwin":
            subprocess.Popen(["open", path])
        else:
            subprocess.Popen(["xdg-open", path])

    def _start_download(self):
        self.start_btn.configure(state="disabled", text="Downloading...")
        self.progress_bar.pack(padx=20, pady=(0, 20), fill="x")
        self.progress_bar.set(0)
        
        self.app.download_manager.start_download(
            progress_callback=self._update_progress,
            completion_callback=self._on_complete
        )

    def _update_progress(self, progress, status):
        # Called from thread, schedule on main loop
        self.after(0, lambda: self._update_progress_safe(progress, status))

    def _update_progress_safe(self, progress, status):
        self.progress_bar.set(progress)
        self.status_label.configure(text=status)

    def _on_complete(self):
        self.after(0, self._on_complete_safe)

    def _on_complete_safe(self):
        self.start_btn.configure(state="normal", text="Start Downloads 🚀")
        self.progress_bar.pack_forget()
        self.status_label.configure(text="All Downloads Complete!")
        self.app.download_manager.clear_queue()
        self._refresh_list()

    def _bind_mouse_wheel(self, event):
        self.queue_list.bind_all("<Button-4>", self._on_mouse_wheel)
        self.queue_list.bind_all("<Button-5>", self._on_mouse_wheel)
        # Windows/Mac support just in case
        self.queue_list.bind_all("<MouseWheel>", self._on_mouse_wheel)

    def _unbind_mouse_wheel(self, event):
        current = self.winfo_containing(event.x_root, event.y_root)
        try:
            if current and str(current).startswith(str(self.queue_list)):
                return
        except:
            pass

        self.queue_list.unbind_all("<Button-4>")
        self.queue_list.unbind_all("<Button-5>")
        self.queue_list.unbind_all("<MouseWheel>")


    def _on_mouse_wheel(self, event):
        # Linux uses Button-4 (up) and Button-5 (down)
        # Windows/Mac uses delta on MouseWheel
        if event.num == 4:
            self.queue_list._parent_canvas.yview_scroll(-1, "units")
        elif event.num == 5:
            self.queue_list._parent_canvas.yview_scroll(1, "units")
        else:
            # Windows/Mac
            if event.delta > 0:
                 self.queue_list._parent_canvas.yview_scroll(-1, "units")
            else:
                 self.queue_list._parent_canvas.yview_scroll(1, "units")

