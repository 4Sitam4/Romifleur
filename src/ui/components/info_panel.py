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
        self._setup_ui()
        self._setup_ui()
        
        # Scroll Fix bindings
        self.bind("<Enter>", self._bind_mouse_wheel)
        self.bind("<Leave>", self._unbind_mouse_wheel)
        
        self.show_default()


    def _setup_ui(self):
        # We'll use pack for simplicity
        pass

    def clear(self):
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
        
        # Cover
        if data.get("image_url"):
            # Load async image?
            # Creating another thread for image loading might be excessive inside the UI update?
            # Actually requests are blocking. 
            # Ideally fetch image in the background thread too.
            # Let's fix _fetch_and_show to include image fetching.
            # But get_metadata returns URL. 
            pass
        
        # Note: We need to handle image loading carefully.
        # Let's respawn a lightweight thread for image if URL exists, or just do it in the previous thread.
        # Reworking _fetch_and_show slightly in next iter, or here.
        
        # Title
        ctk.CTkLabel(self, text=data["title"], font=ctk.CTkFont(size=18, weight="bold"), wraplength=180).pack(pady=(20, 5))
        
        # Image Placeholder (we'll update it)
        self.image_label = ctk.CTkLabel(self, text="[No Image]")
        self.image_label.pack(pady=10)
        
        if data.get("image_url"):
             threading.Thread(target=self._load_image_async, args=(data["image_url"],)).start()
        
        # Desc
        ctk.CTkLabel(self, text=data["description"], wraplength=180, justify="left", anchor="w").pack(pady=10, fill="x")
        
        # Date
        if data.get("date"):
            ctk.CTkLabel(self, text=f"Released: {data['date']}", text_color="gray").pack(pady=(5, 0))
            
        # Details Grid
        details_frame = ctk.CTkFrame(self, fg_color="transparent")
        details_frame.pack(pady=10, fill="x")
        
        # Helper to add detail rows
        def add_detail(label, value):
            if value and value != "Unknown":
                row = ctk.CTkFrame(details_frame, fg_color="transparent")
                row.pack(fill="x", pady=1)
                ctk.CTkLabel(row, text=f"{label}: ", font=ctk.CTkFont(size=11, weight="bold"), width=80, anchor="e").pack(side="left")
                ctk.CTkLabel(row, text=value, font=ctk.CTkFont(size=11), anchor="w", wraplength=120).pack(side="left", fill="x", expand=True)

        add_detail("Genre", data.get("genres"))
        add_detail("Dev", data.get("developer"))
        add_detail("Pub", data.get("publisher"))
        add_detail("Players", data.get("players"))
        add_detail("Rating", data.get("rating"))

        # Provider
        ctk.CTkLabel(self, text=f"Source: {data['provider']}", font=ctk.CTkFont(size=10), text_color="gray").pack(pady=(20, 5))


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

