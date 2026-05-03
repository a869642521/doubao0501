from pydantic import BaseModel
from typing import Optional


class ChatMessage(BaseModel):
    role: str  # "system", "user", "assistant"
    content: str


class ChatCompletionRequest(BaseModel):
    agent_id: str
    system_prompt: str
    messages: list[ChatMessage]
    stream: bool = True
    temperature: float = 0.8
    max_tokens: int = 1024


class MemoryExtractRequest(BaseModel):
    agent_id: str
    user_id: str
    messages: list[ChatMessage]


class MemorySearchRequest(BaseModel):
    agent_id: str
    user_id: str
    query: str
    limit: int = 5


class MemoryEntry(BaseModel):
    id: Optional[str] = None
    content: str
    level: str
    metadata: dict = {}
