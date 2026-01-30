"""
RetroAchievements Router - API endpoints for RA integration
"""
from fastapi import APIRouter, Request, Query
from typing import List

from ..models.schemas import RAGame, RAValidationResponse

router = APIRouter()


@router.get("/games/{console_key}")
async def get_ra_games(request: Request, console_key: str):
    """Get list of games with RetroAchievements for a console."""
    ra_manager = request.app.state.ra_manager
    
    games = ra_manager.get_supported_games(console_key)
    
    return {
        "console": console_key,
        "count": len(games),
        "games": games
    }


@router.get("/check/{console_key}/{filename}")
async def check_rom_compatibility(request: Request, console_key: str, filename: str):
    """Check if a specific ROM has RetroAchievements support."""
    ra_manager = request.app.state.ra_manager
    
    is_compatible = ra_manager.check_rom_compatibility(console_key, filename)
    
    return {
        "filename": filename,
        "console": console_key,
        "has_achievements": is_compatible
    }


@router.get("/validate", response_model=RAValidationResponse)
async def validate_api_key(request: Request, key: str = Query(..., description="RA API Key to validate")):
    """Validate a RetroAchievements API key."""
    ra_manager = request.app.state.ra_manager
    
    is_valid = ra_manager.validate_key(key)
    
    return RAValidationResponse(
        valid=is_valid,
        message="API key is valid" if is_valid else "Invalid API key"
    )
