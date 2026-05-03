from fastapi import APIRouter
from app.models.schemas import MemoryExtractRequest, MemorySearchRequest
from app.services.memory_service import extract_memories

router = APIRouter()


@router.post("/extract")
async def extract(request: MemoryExtractRequest):
    """Extract memorable information from conversation messages."""
    messages = [{"role": m.role, "content": m.content} for m in request.messages]
    memories = await extract_memories(messages)
    return {"agent_id": request.agent_id, "user_id": request.user_id, "memories": memories}


@router.post("/search")
async def search(request: MemorySearchRequest):
    """Search memories by semantic similarity (placeholder for pgvector integration)."""
    # TODO: implement pgvector similarity search
    return {"agent_id": request.agent_id, "results": []}
