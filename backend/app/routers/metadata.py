"""
Metadata Router - API endpoints for game metadata
"""
from fastapi import APIRouter, Request

from ..models.schemas import GameMetadata

router = APIRouter()


@router.get("/{console_key}/{filename}", response_model=GameMetadata)
async def get_metadata(request: Request, console_key: str, filename: str):
    """
    Get metadata for a specific ROM file.
    
    Returns title, description, release date, box art URL, etc.
    Data is fetched from TheGamesDB and cached locally.
    """
    metadata_manager = request.app.state.metadata_manager
    
    data = metadata_manager.get_metadata(console_key, filename)
    
    return GameMetadata(
        title=data.get("title", filename),
        description=data.get("description", ""),
        release_date=data.get("date", ""),
        image_url=data.get("image_url", ""),
        provider=data.get("provider", ""),
        has_achievements=data.get("has_achievements", False)
    )
