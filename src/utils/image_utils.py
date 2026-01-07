
import os
import sys
from PIL import Image, ImageTk
import customtkinter as ctk

class ImageUtils:
    @staticmethod
    def load_image(path, size=None):
        # PyInstaller bundled path fix
        if hasattr(sys, '_MEIPASS'):
            # If path matches an asset, resolve relative to MEIPASS
            # Note: The user passes relative paths like 'assets/logo.png' 
            # Our spec file bundles: ('assets', 'assets') -> root/assets
            bundled_path = os.path.join(sys._MEIPASS, path)
            if os.path.exists(bundled_path):
                path = bundled_path
        
        if not os.path.exists(path):
            return None
        try:
            pil_image = Image.open(path)
            if size:
                return ctk.CTkImage(light_image=pil_image, dark_image=pil_image, size=size)
            return ctk.CTkImage(light_image=pil_image, dark_image=pil_image)
        except Exception as e:
            print(f"Error loading image {path}: {e}")
            return None

    @staticmethod
    def set_window_icon(window, path):
        if os.path.exists(path):
            try:
                icon_image = Image.open(path)
                photo = ImageTk.PhotoImage(icon_image)
                window.wm_iconphoto(False, photo)
            except Exception as e:
                print(f"Error setting icon {path}: {e}")
