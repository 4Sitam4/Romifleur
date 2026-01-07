
import logging
import sys
import os
from logging.handlers import RotatingFileHandler

def setup_logging(debug_mode=False):
    """
    Sets up logging to file and console.
    Redirects stdout and stderr to the logger.
    """
    log_level = logging.DEBUG if debug_mode else logging.INFO
    
    # Determine log path - try to put it next to executable or in cwd
    if getattr(sys, 'frozen', False):
        application_path = os.path.dirname(sys.executable)
    else:
        application_path = os.getcwd()
        
    log_file = os.path.join(application_path, "debug.log")
    
    # Configure root logger
    logger = logging.getLogger()
    logger.setLevel(log_level)
    
    # Prevent "No handlers could be found" warning and recursion via lastResort
    logger.addHandler(logging.NullHandler())
    
    # File Handler
    if debug_mode:
        try:
            file_handler = RotatingFileHandler(log_file, maxBytes=1024*1024, backupCount=1, encoding='utf-8')
            file_handler.setLevel(log_level)
            file_formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
            file_handler.setFormatter(file_formatter)
            logger.addHandler(file_handler)
        except PermissionError:
            # Fallback to home dir if installation dir is read-only
            log_file = os.path.join(os.path.expanduser("~"), "romifleur_debug.log")
            try:
                file_handler = RotatingFileHandler(log_file, maxBytes=1024*1024, backupCount=1, encoding='utf-8')
                file_handler.setLevel(log_level)
                file_handler.setFormatter(file_formatter)
                logger.addHandler(file_handler)
            except Exception:
                pass # Give up if we can't write logs anywhere

    # Console Handler (if we want to see it in terminal window too)
    if sys.stdout is not None:
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(log_level)
        console_formatter = logging.Formatter('%(levelname)s: %(message)s')
        console_handler.setFormatter(console_formatter)
        logger.addHandler(console_handler)
    
    # Redirect stdout and stderr
    sys.stdout = StreamToLogger(logger, logging.INFO)
    sys.stderr = StreamToLogger(logger, logging.ERROR)
    
    logging.info(f"Logging started. Debug mode: {debug_mode}")
    if debug_mode:
        logging.info(f"Log file: {log_file}")
    
class StreamToLogger(object):
    """
    Fake file-like stream object that redirects writes to a logger instance.
    """
    def __init__(self, logger, log_level=logging.INFO):
        self.logger = logger
        self.log_level = log_level
        self.linebuf = ''
        self.processing = False

    def write(self, buf):
        # Recursion guard
        if self.processing:
            return
            
        self.processing = True
        try:
            for line in buf.rstrip().splitlines():
                if line.strip():
                     self.logger.log(self.log_level, line.rstrip())
        except Exception:
            pass
        finally:
            self.processing = False

    def flush(self):
        pass
