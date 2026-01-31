import uvicorn
import multiprocessing
import os
import sys

# Add the current directory to path so we can import app
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.main import app

if __name__ == "__main__":
    multiprocessing.freeze_support()
    # Log startup
    print("Starting Romifleur Backend on http://127.0.0.1:8000")
    uvicorn.run(app, host="127.0.0.1", port=8000, log_level="info")
