"""
Consoles Router - API endpoints for console catalog
"""
from fastapi import APIRouter, Request
from typing import List

from ..models.schemas import ConsoleInfo, CategoryConsoles, ConsolesResponse

router = APIRouter()


@router.get("", response_model=ConsolesResponse)
async def get_all_consoles(request: Request):
    """Get full console catalog grouped by category."""
    consoles = request.app.state.rom_manager.get_all_consoles()
    
    categories = []
    for category_name, category_consoles in consoles.items():
        console_list = []
        for key, data in category_consoles.items():
            console_list.append(ConsoleInfo(
                key=key,
                name=data.get("name", key),
                folder=data.get("folder", key.lower()),
                url=data.get("url", ""),
                exts=data.get("exts", []),
                best_games=data.get("best_games", [])
            ))
        categories.append(CategoryConsoles(
            category=category_name,
            consoles=console_list
        ))
    
    return ConsolesResponse(categories=categories)


@router.get("/{category}/{console_key}", response_model=ConsoleInfo)
async def get_console(request: Request, category: str, console_key: str):
    """Get specific console information."""
    info = request.app.state.rom_manager.get_console_info(category, console_key)
    
    if not info:
        return ConsoleInfo(
            key=console_key,
            name="Unknown",
            folder="unknown",
            url="",
            exts=[]
        )
    
    return ConsoleInfo(
        key=console_key,
        name=info.get("name", console_key),
        folder=info.get("folder", console_key.lower()),
        url=info.get("url", ""),
        exts=info.get("exts", []),
        best_games=info.get("best_games", [])
    )
