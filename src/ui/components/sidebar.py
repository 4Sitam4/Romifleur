
import customtkinter as ctk
import os
from ...utils.image_utils import ImageUtils
from ...utils.icons import Icons
from .info_panel import InfoPanel
import platform


class Sidebar(ctk.CTkFrame):
    def __init__(self, master, app_context, on_console_select, **kwargs):
        super().__init__(master, **kwargs)
        self.app = app_context
        self.on_console_select = on_console_select
        
        self.category_frames = {}
        self.category_buttons = {}
        self.active_btn = None
        
        self._setup_ui()
        self._populate_list()

    def _setup_ui(self):
        # Logo
        self._setup_logo()
        
        # Open Folder Button (Removed)


        # Settings (Bottom)
        self.settings_btn = ctk.CTkButton(self, text=Icons.SETTINGS, fg_color="transparent", border_width=1, 
                                          command=self._open_settings)
        self.settings_btn.pack(side="bottom", padx=20, pady=20, fill="x")
        

        # Info Panel (Top half, expands)
        self.info_panel.pack(fill="both", expand=True, padx=10, pady=10)


        # Console List (Bottom half, expands)
        self.console_list_frame = ctk.CTkScrollableFrame(self, label_text="Consoles")
        self.console_list_frame.pack(fill="both", expand=True, padx=10, pady=(10, 0))

        
        # Fix scroll logic (focus on hover)
        self.console_list_frame.bind("<Enter>", self._bind_mouse_wheel)
        self.console_list_frame.bind("<Leave>", self._unbind_mouse_wheel)


    def _setup_logo(self):
        # Replace logo with InfoPanel
        self.info_panel = InfoPanel(self, self.app, width=200, height=300) # approximate height, it's scrollable
        # We want it to take some space but not too much? 
        # User said "replace the logo". Logo was packed with pady 20.
        # Maybe limit height or let it expand slightly?
        # User said "scrollable frame".
        # User said "scrollable frame".
        # self.info_panel.pack(fill="x", padx=10, pady=10) # Moved to _setup_ui pack order logic
        pass



    def _populate_list(self):
        consoles = self.app.rom_manager.consoles
        # Iterate over categories
        for category, consoles_data in consoles.items():
            self._create_category_group(category, consoles_data)

    def _create_category_group(self, category, consoles_data):
        group_frame = ctk.CTkFrame(self.console_list_frame, fg_color="transparent")
        group_frame.pack(fill="x", pady=2)

        # Header Button
        header_frame = ctk.CTkFrame(group_frame, fg_color="transparent")
        header_frame.pack(fill="x", pady=0)
        
        content_frame = ctk.CTkFrame(group_frame, fg_color="transparent")
        content_frame.pack(fill="x", padx=10, pady=0)
        
        def toggle_category(cat=category):
            frame = self.category_frames[cat]
            btn = self.category_buttons[cat]
            if frame.winfo_viewable():
                frame.pack_forget()
                btn.configure(text=f"{Icons.COLLAPSE} {cat}")
            else:
                frame.pack(fill="x", padx=10, pady=0)
                btn.configure(text=f"{Icons.EXPAND} {cat}")

        btn = ctk.CTkButton(header_frame, text=f"{Icons.EXPAND} {category}", fg_color="#333", hover_color="#444", 
                            anchor="w", command=toggle_category, font=("Arial", 13, "bold"))
        btn.pack(fill="x")
        
        self.category_frames[category] = content_frame
        self.category_buttons[category] = btn

        sorted_keys = sorted(consoles_data.keys(), key=lambda k: consoles_data[k]['name'])
        for key in sorted_keys:
            name = consoles_data[key].get('name', key)
            c_btn = ctk.CTkButton(content_frame, text=name, anchor="w", fg_color="transparent", 
                                  hover_color="#3A3A3A", height=24,
                                  command=lambda col=category, k=key: self._handle_selection(col, k))
            c_btn.pack(fill="x", pady=1)
            
            # Store if we need to access via key later, but for now active_btn is enough tracking via clicking
            # Actually we need the button instance to change its color inside lambda, 
            # but better to pass the click event or binding, or just better structure.
            # Lambda constraints: We can't easily pass self.c_btn because it's overwritten
            # Let's use a factory or immediate binding. 
            
            # Better approach:
            self._bind_button(c_btn, category, key)

    def _bind_button(self, btn, category, key):
        btn.configure(command=lambda: self._handle_selection(btn, category, key))

    def _handle_selection(self, btn, category, key):
        # Reset previous
        if self.active_btn:
            self.active_btn.configure(fg_color="transparent")
            
        # Set new
        self.active_btn = btn
        self.active_btn.configure(fg_color=["#3a7ebf", "#1f538d"]) # Standard active blue
        
        # Callback
        self.on_console_select(category, key)


    def _open_settings(self):
        # Import dynamically to avoid circular import if SettingsWindow is in same package
        # For now assume we pass a callback or signal to Main Window to open settings? 
        # Or just open a Toplevel here.
        from ...ui.settings_window import SettingsWindow
        SettingsWindow(self.winfo_toplevel(), self.app)

    def _bind_mouse_wheel(self, event):
        self.console_list_frame.bind_all("<Button-4>", self._on_mouse_wheel)
        self.console_list_frame.bind_all("<Button-5>", self._on_mouse_wheel)
        # Windows/Mac support just in case
        self.console_list_frame.bind_all("<MouseWheel>", self._on_mouse_wheel)

    def _unbind_mouse_wheel(self, event):
        # Check if we are still inside the frame (or its children)
        # unbind only if we really left the area
        current = self.winfo_containing(event.x_root, event.y_root)
        try:
            if current and str(current).startswith(str(self.console_list_frame)):
                return
        except:
            pass

        self.console_list_frame.unbind_all("<Button-4>")
        self.console_list_frame.unbind_all("<Button-5>")
        self.console_list_frame.unbind_all("<MouseWheel>")


    def _on_mouse_wheel(self, event):
        # Linux uses Button-4 (up) and Button-5 (down)
        # Windows/Mac uses delta on MouseWheel
        if event.num == 4:
            self.console_list_frame._parent_canvas.yview_scroll(-1, "units")
        elif event.num == 5:
            self.console_list_frame._parent_canvas.yview_scroll(1, "units")
        else:
            # Windows/Mac
            factor = 1
            if platform.system() == "Windows":
                factor = 20
            
            if event.delta > 0:
                 self.console_list_frame._parent_canvas.yview_scroll(-1 * factor, "units")
            else:
                 self.console_list_frame._parent_canvas.yview_scroll(1 * factor, "units")

