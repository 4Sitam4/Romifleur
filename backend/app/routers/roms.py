"""
ROMs Router - API endpoints for ROM listing and searching
"""
from fastapi import APIRouter, Request, Query
from typing import List, Optional

from ..models.schemas import RomFile, RomListResponse

router = APIRouter()


@router.get("/{category}/{console_key}", response_model=RomListResponse)
async def get_roms(
    request: Request,
    category: str,
    console_key: str,
    q: str = Query("", description="Search query"),
    regions: Optional[str] = Query(None, description="Comma-separated regions: Europe,USA,Japan"),
    hide_demos: bool = Query(True, description="Hide demo ROMs"),
    hide_betas: bool = Query(True, description="Hide beta/prototype ROMs"),
    deduplicate: bool = Query(True, description="Show only best version of each game"),
    only_ra: bool = Query(False, description="Show only games with RetroAchievements")
):
    """
    Get ROM list for a console with optional filtering.
    
    Examples:
    - /api/roms/Nintendo/NES - All NES ROMs
    - /api/roms/Nintendo/NES?q=mario - Search for "mario"
    - /api/roms/Nintendo/NES?regions=Europe,France - Only EU/FR ROMs
    """
    rom_manager = request.app.state.rom_manager
    ra_manager = request.app.state.ra_manager
    
    # Parse regions
    region_list = None
    if regions:
        region_list = [r.strip() for r in regions.split(",")]
    
    # Get filtered ROM list
    roms = rom_manager.search(
        category=category,
        console_key=console_key,
        query=q,
        regions=region_list,
        hide_demos=hide_demos,
        hide_betas=hide_betas,
        deduplicate=deduplicate
    )
    
    # Get RA games for compatibility checking
    ra_games = ra_manager.get_supported_games(console_key)
    
    # Build response
    files = []
    for rom in roms:
        has_achievements = ra_manager.is_compatible(rom["name"], ra_games) if ra_games else False
        
        # Filter by RA support if requested
        if only_ra and not has_achievements:
            continue
            
        files.append(RomFile(
            filename=rom["name"],
            size=rom.get("size", "N/A"),
            has_achievements=has_achievements
        ))
    
    # Get console name
    console_info = rom_manager.get_console_info(category, console_key)
    console_name = console_info.get("name", console_key) if console_info else console_key
    
    return RomListResponse(
        console_key=console_key,
        console_name=console_name,
        total=len(files),
        files=files
    )


@router.post("/{category}/{console_key}/refresh")
async def refresh_rom_list(request: Request, category: str, console_key: str):
    """Force refresh ROM list from source (clears cache for this console)."""
    rom_manager = request.app.state.rom_manager
    
    # Force reload
    roms = rom_manager.fetch_file_list(category, console_key, force_reload=True)
    
    return {
        "status": "refreshed",
        "console": console_key,
        "count": len(roms)
    }
