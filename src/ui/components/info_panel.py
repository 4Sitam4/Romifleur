import customtkinter as ctk
import threading
from PIL import Image, ImageTk
import requests
from io import BytesIO
from ...utils.image_utils import ImageUtils

class InfoPanel(ctk.CTkScrollableFrame):
    def __init__(self, master, app_context, **kwargs):
        super().__init__(master, **kwargs)
        self.app = app_context
        self.desc_label = None
        self._setup_ui()
        
        # Scroll Fix bindings
        self.bind("<Enter>", self._bind_mouse_wheel)
        self.bind("<Leave>", self._unbind_mouse_wheel)
        

        
        self.show_default()




    def _setup_ui(self):
        # We'll use pack for simplicity
        pass

    def clear(self):
        self.desc_label = None
        for widget in self.winfo_children():
            widget.destroy()

    def show_default(self):
        self.clear()
        
        # Logo
        logo_img = ImageUtils.load_image("logo-romifleur.png", size=(180, 180))
        if not logo_img:
            # Try assets
            logo_img = ImageUtils.load_image("assets/logo-romifleur.png", size=(180, 180))
            
        if logo_img:
            ctk.CTkLabel(self, text="", image=logo_img).pack(pady=20)
        else:
            ctk.CTkLabel(self, text="Romifleur", font=ctk.CTkFont(size=24, weight="bold")).pack(pady=20)
            
        # Title
        ctk.CTkLabel(self, text="Romifleur", font=ctk.CTkFont(size=20, weight="bold")).pack(pady=(0, 5))
        
        # Description
        desc_text = "The Modern ROM Manager.\nOrganize, Download, and Discover retro games with ease."
        ctk.CTkLabel(self, text=desc_text, wraplength=180, justify="center").pack(pady=10)
        
        # Date
        ctk.CTkLabel(self, text="Released: 03/01/2026", text_color="gray").pack(pady=(10, 20))

    def show_game(self, category, console, filename):
        # Show loader first?
        self.clear()
        
        # Loader
        loader = ctk.CTkLabel(self, text="Loading metadata...")
        loader.pack(pady=50)
        
        threading.Thread(target=self._fetch_and_show, args=(category, console, filename)).start()

    def _fetch_and_show(self, category, console, filename):
        # Ensure MetadataManager exists (we'll initialize it in App or here if missing)
        # But better to have it in AppContext
        if not hasattr(self.app, 'metadata_manager'):
            print("MetadataManager not initialized!")
            return

        data = self.app.metadata_manager.get_metadata(console, filename)
        
        self.after(0, lambda: self._update_ui(data))

    def _update_ui(self, data):
        self.clear()
        
        # --- Header Section ---
        # Title
        ctk.CTkLabel(self, text=data["title"], font=ctk.CTkFont(size=18, weight="bold"), wraplength=200, justify="center").pack(pady=(20, 10), fill="x")
        
        # --- Image Section ---
        self.image_label = ctk.CTkLabel(self, text="", width=180, height=180) # Fixed size placeholder
        self.image_label.pack(pady=10)
        
        if data.get("image_url"):
             threading.Thread(target=self._load_image_async, args=(data["image_url"],)).start()
        else:
             self.image_label.configure(text="[No Image]")

        # --- Metadata Grid Section ---
        # Use a grid frame for perfect alignment of labels and values
        meta_frame = ctk.CTkFrame(self, fg_color="transparent")
        meta_frame.pack(fill="x", pady=10, padx=10)
        
        meta_frame.grid_columnconfigure(0, weight=0) # Labels fixed/minimal width
        meta_frame.grid_columnconfigure(1, weight=1) # Values expand
        
        row_idx = 0
        def add_row(label, value):
            nonlocal row_idx
            if value and value != "Unknown":
                # Label
                ctk.CTkLabel(meta_frame, text=f"{label}:", font=ctk.CTkFont(size=11, weight="bold"), 
                             anchor="w", width=80).grid(row=row_idx, column=0, sticky="nw", padx=(0, 5), pady=2)
                # Value
                ctk.CTkLabel(meta_frame, text=value, font=ctk.CTkFont(size=11), 
                             anchor="w", justify="left", wraplength=130).grid(row=row_idx, column=1, sticky="nw", pady=2)
                row_idx += 1

        if data.get("date"):
            add_row("Released", data["date"])
        
        add_row("Genre", data.get("genres"))
        add_row("Developer", data.get("developer"))
        add_row("Publisher", data.get("publisher"))
        add_row("Players", data.get("players"))
        add_row("Rating", data.get("rating"))

        # --- Description Section ---
        ctk.CTkLabel(self, text="Overview", font=ctk.CTkFont(size=12, weight="bold"), anchor="w").pack(fill="x", padx=10, pady=(15, 5))
        
        desc = data.get("description", "No description available.")
        self.desc_label = ctk.CTkLabel(self, text=desc, font=ctk.CTkFont(size=12), justify="left", anchor="nw", wraplength=180)
        self.desc_label.pack(fill="x", padx=10, pady=(0, 10))

        # --- Footer ---
        ctk.CTkLabel(self, text=f"Source: {data['provider']}", font=ctk.CTkFont(size=10), text_color="gray").pack(side="bottom", pady=20)


    def _load_image_async(self, url):
        try:
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                img_data = BytesIO(response.content)
                img = Image.open(img_data)
                # Resize keeping aspect ratio
                # Target width 180
                w, h = img.size
                ratio = 180 / w
                new_h = int(h * ratio)
                

                
                # Use CTkImage
                ctk_img = ctk.CTkImage(light_image=img, dark_image=img, size=(180, new_h))
                
                self.after(0, lambda: self._update_image(ctk_img))
        except Exception as e:
            print(f"Image load error: {e}")

    def _update_image(self, img_ctk):
        # Keep ref
        self._current_image = img_ctk
        self.image_label.configure(image=img_ctk, text="")

    def _bind_mouse_wheel(self, event):
        self.bind_all("<Button-4>", self._on_mouse_wheel)
        self.bind_all("<Button-5>", self._on_mouse_wheel)
        self.bind_all("<MouseWheel>", self._on_mouse_wheel)

    def _unbind_mouse_wheel(self, event):
        current = self.winfo_containing(event.x_root, event.y_root)
        try:
            if current and str(current).startswith(str(self)):
                return
        except:
            pass

        self.unbind_all("<Button-4>")
        self.unbind_all("<Button-5>")
        self.unbind_all("<MouseWheel>")

    def _on_mouse_wheel(self, event):
        if event.num == 4:
            self._parent_canvas.yview_scroll(-1, "units")
        elif event.num == 5:
            self._parent_canvas.yview_scroll(1, "units")
        else:
            if event.delta > 0:
                 self._parent_canvas.yview_scroll(-1, "units")
            else:
                 self._parent_canvas.yview_scroll(1, "units")

