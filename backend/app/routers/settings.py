"""
Settings Router - API endpoints for user settings
"""
from fastapi import APIRouter, Request

from ..models.schemas import UserSettings, UpdateSettingsRequest

router = APIRouter()


@router.get("/", response_model=UserSettings)
async def get_settings(request: Request):
    """Get current user settings."""
    config = request.app.state.config
    
    return UserSettings(
        roms_path=config.settings.get("roms_path", "ROMs"),
        ra_api_key=config.settings.get("ra_api_key", "")
    )


@router.put("/")
async def update_settings(request: Request, settings: UpdateSettingsRequest):
    """Update user settings."""
    config = request.app.state.config
    
    success = config.update_settings(
        roms_path=settings.roms_path,
        ra_api_key=settings.ra_api_key
    )
    
    return {
        "success": success,
        "settings": {
            "roms_path": config.settings.get("roms_path"),
            "ra_api_key": "***" if config.settings.get("ra_api_key") else ""
        }
    }


@router.get("/download-path")
async def get_download_path(request: Request):
    """Get resolved download path (creates if needed)."""
    config = request.app.state.config
    path = config.get_download_path()
    
    return {"path": path}


@router.post("/download-path")
async def set_download_path(request: Request, path: str):
    """Set download path."""
    config = request.app.state.config
    
    success = config.update_settings(roms_path=path)
    resolved_path = config.get_download_path()
    
    return {
        "success": success,
        "path": resolved_path
    }
