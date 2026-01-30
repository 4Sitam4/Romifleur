"""
Romifleur Backend - FastAPI Application
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .routers import consoles, roms, downloads, metadata, settings, retroachievements
from .services.config_manager import ConfigManager
from .services.rom_manager import RomManager
from .services.download_manager import DownloadManager
from .services.metadata_manager import MetadataManager
from .services.ra_manager import RetroAchievementsManager

# Initialize app
app = FastAPI(
    title="Romifleur API",
    description="Backend API for Romifleur ROM downloader",
    version="2.0.0"
)

# CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Flutter apps on all platforms
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize core services (singleton pattern)
config_manager = ConfigManager()
rom_manager = RomManager(config_manager)
ra_manager = RetroAchievementsManager(config_manager)
metadata_manager = MetadataManager(config_manager, ra_manager)
download_manager = DownloadManager(rom_manager)

# Store in app state for access in routers
app.state.config = config_manager
app.state.rom_manager = rom_manager
app.state.ra_manager = ra_manager
app.state.metadata_manager = metadata_manager
app.state.download_manager = download_manager

# Include routers
app.include_router(consoles.router, prefix="/api/consoles", tags=["Consoles"])
app.include_router(roms.router, prefix="/api/roms", tags=["ROMs"])
app.include_router(downloads.router, prefix="/api/downloads", tags=["Downloads"])
app.include_router(metadata.router, prefix="/api/metadata", tags=["Metadata"])
app.include_router(settings.router, prefix="/api/settings", tags=["Settings"])
app.include_router(retroachievements.router, prefix="/api/ra", tags=["RetroAchievements"])


@app.get("/")
async def root():
    return {"message": "Romifleur API v2.0.0", "docs": "/docs"}


@app.get("/health")
async def health_check():
    return {"status": "healthy"}
