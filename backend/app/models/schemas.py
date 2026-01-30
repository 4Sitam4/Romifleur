"""
Pydantic models for API request/response schemas
"""
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any


# Console Models
class ConsoleInfo(BaseModel):
    """Single console information"""
    key: str
    name: str
    folder: str
    url: str
    exts: List[str]
    best_games: List[str] = []


class CategoryConsoles(BaseModel):
    """Consoles grouped by category"""
    category: str
    consoles: List[ConsoleInfo]


class ConsolesResponse(BaseModel):
    """Full console catalog response"""
    categories: List[CategoryConsoles]


# ROM Models
class RomFile(BaseModel):
    """Single ROM file information"""
    filename: str
    size: str = "N/A"
    has_achievements: bool = False


class RomListResponse(BaseModel):
    """ROM list for a console"""
    console_key: str
    console_name: str
    total: int
    files: List[RomFile]


class RomSearchParams(BaseModel):
    """Search parameters for ROM filtering"""
    query: str = ""
    regions: List[str] = Field(default_factory=lambda: ["Europe", "USA", "Japan"])
    hide_demos: bool = True
    hide_betas: bool = True
    deduplicate: bool = True


# Download Models
class DownloadItem(BaseModel):
    """Item in download queue"""
    category: str
    console: str
    filename: str
    size: str = "N/A"


class DownloadQueueResponse(BaseModel):
    """Download queue state"""
    items: List[DownloadItem]
    total_count: int
    is_downloading: bool


class DownloadProgress(BaseModel):
    """Download progress update (for WebSocket)"""
    current: int
    total: int
    percentage: float
    status: str
    current_file: Optional[str] = None


class AddToQueueRequest(BaseModel):
    """Request to add item to download queue"""
    category: str
    console: str
    filename: str
    size: str = "N/A"


class AddToQueueBatchRequest(BaseModel):
    """Request to add multiple items to queue"""
    items: List[AddToQueueRequest]


# Metadata Models
class GameMetadata(BaseModel):
    """Game metadata from TheGamesDB or RetroAchievements"""
    title: str
    description: str = ""
    release_date: str = ""
    image_url: str = ""
    provider: str = ""
    has_achievements: bool = False


# Settings Models
class UserSettings(BaseModel):
    """User settings"""
    roms_path: str = "ROMs"
    ra_api_key: str = ""


class UpdateSettingsRequest(BaseModel):
    """Request to update settings"""
    roms_path: Optional[str] = None
    ra_api_key: Optional[str] = None


# RetroAchievements Models
class RAGame(BaseModel):
    """RetroAchievements game entry"""
    id: int = Field(alias="ID")
    title: str = Field(alias="Title")

    class Config:
        populate_by_name = True


class RAValidationResponse(BaseModel):
    """API key validation response"""
    valid: bool
    message: str = ""
