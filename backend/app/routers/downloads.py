"""
Downloads Router - API endpoints for download queue and progress
"""
from fastapi import APIRouter, Request, WebSocket, WebSocketDisconnect
from typing import List
import asyncio
import json

from ..models.schemas import (
    DownloadItem, DownloadQueueResponse, DownloadProgress,
    AddToQueueRequest, AddToQueueBatchRequest
)

router = APIRouter()


@router.get("/queue", response_model=DownloadQueueResponse)
async def get_queue(request: Request):
    """Get current download queue."""
    dm = request.app.state.download_manager
    
    items = [
        DownloadItem(
            category=item["category"],
            console=item["console"],
            filename=item["filename"],
            size=item["size"]
        )
        for item in dm.get_queue()
    ]
    
    return DownloadQueueResponse(
        items=items,
        total_count=len(items),
        is_downloading=dm.is_downloading
    )


@router.post("/queue")
async def add_to_queue(request: Request, item: AddToQueueRequest):
    """Add single item to download queue."""
    dm = request.app.state.download_manager
    
    added = dm.add_to_queue(
        category=item.category,
        console=item.console,
        filename=item.filename,
        size=item.size
    )
    
    return {
        "success": added,
        "queue_count": dm.get_queue_count()
    }


@router.post("/queue/batch")
async def add_batch_to_queue(request: Request, batch: AddToQueueBatchRequest):
    """Add multiple items to download queue."""
    dm = request.app.state.download_manager
    
    items_dicts = [
        {
            "category": item.category,
            "console": item.console,
            "filename": item.filename,
            "size": item.size
        }
        for item in batch.items
    ]
    
    added_count = dm.add_batch_to_queue(items_dicts)
    
    return {
        "added": added_count,
        "total_requested": len(batch.items),
        "queue_count": dm.get_queue_count()
    }


@router.delete("/queue/{index}")
async def remove_from_queue(request: Request, index: int):
    """Remove item from queue by index."""
    dm = request.app.state.download_manager
    
    removed = dm.remove_from_queue(index)
    
    return {
        "success": removed,
        "queue_count": dm.get_queue_count()
    }


@router.delete("/queue")
async def clear_queue(request: Request):
    """Clear entire download queue."""
    dm = request.app.state.download_manager
    dm.clear_queue()
    
    return {"success": True, "queue_count": 0}


@router.post("/start")
async def start_downloads(request: Request):
    """Start downloading queued items."""
    dm = request.app.state.download_manager
    
    if dm.is_downloading:
        return {"success": False, "message": "Already downloading"}
    
    if dm.get_queue_count() == 0:
        return {"success": False, "message": "Queue is empty"}
    
    started = dm.start_download()
    
    return {
        "success": started,
        "total": dm.total_count
    }


@router.get("/progress", response_model=DownloadProgress)
async def get_progress(request: Request):
    """Get current download progress (polling endpoint)."""
    dm = request.app.state.download_manager
    progress = dm.get_progress()
    
    return DownloadProgress(
        current=progress["current"],
        total=progress["total"],
        percentage=progress["percentage"],
        status=progress["status"],
        current_file=progress.get("current_file")
    )


@router.websocket("/ws/progress")
async def websocket_progress(websocket: WebSocket):
    """WebSocket endpoint for real-time download progress."""
    await websocket.accept()
    
    dm = websocket.app.state.download_manager
    
    # Create callback for progress updates
    async def send_progress(data):
        try:
            await websocket.send_json(data)
        except Exception:
            pass
    
    # Wrapper to call async from sync callback
    def progress_callback(data):
        try:
            asyncio.run(send_progress(data))
        except RuntimeError:
            # Already in async context, use different approach
            loop = asyncio.get_event_loop()
            loop.create_task(send_progress(data))
    
    dm.register_progress_callback(progress_callback)
    
    try:
        while True:
            # Keep connection alive, wait for any message or disconnect
            try:
                data = await asyncio.wait_for(websocket.receive_text(), timeout=1.0)
                if data == "ping":
                    await websocket.send_text("pong")
            except asyncio.TimeoutError:
                # Send current progress periodically
                progress = dm.get_progress()
                await websocket.send_json(progress)
    except WebSocketDisconnect:
        dm.unregister_progress_callback(progress_callback)
