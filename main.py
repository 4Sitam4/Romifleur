import sys
import os
import logging
import platform
import ctypes

# X11 workarounds for Linux (must be before any tkinter/ctk imports)
if platform.system() == "Linux":
    os.environ.setdefault("FREETYPE_PROPERTIES", "truetype:interpreter-version=35")
    try:
        x11 = ctypes.CDLL("libX11.so.6")
        x11.XInitThreads()
    except Exception:
        pass
    
    # Disable Tk scaling auto-detection that may cause issues
    try:
        import customtkinter as ctk
        ctk.deactivate_automatic_dpi_awareness()
    except Exception:
        pass

# Ensure src is in path if needed (though local import should work)
sys.path.append(os.path.dirname(os.path.abspath(__file__)))


from src.app import App
from src.utils.logger import setup_logging

if __name__ == "__main__":
    # Check for debug flag
    debug_mode = "--debug" in sys.argv
    setup_logging(debug_mode=debug_mode)
    
    try:
        try:
            from ctypes import windll
            myappid = 'romifleur.v2.gui'
            windll.shell32.SetCurrentProcessExplicitAppUserModelID(myappid)
        except ImportError:
            pass
            
        logging.info("Starting Romifleur...")
        app = App()
        app.run()
    except Exception as e:
        logging.critical("Unhandled exception caused crash", exc_info=True)
        sys.exit(1)

