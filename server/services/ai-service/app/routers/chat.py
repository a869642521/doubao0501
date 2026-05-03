import json
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from app.models.schemas import ChatCompletionRequest
from app.services.llm_gateway import stream_chat_completion

router = APIRouter()

_THINK_PREFIX = "\x00think\x00"

# 与网关侧 voicePlain（Markdown 派生）配合：鼓励结构化正文
_MARKDOWN_STYLE_SUFFIX = (
    "\n\n【输出格式】请使用 Markdown（标题、列表、引用、代码块）组织内容；"
    "关键结论用短句表达，便于朗读与阅读。"
)


@router.post("/completions")
async def chat_completions(request: ChatCompletionRequest):
    """Stream or return chat completion for an agent conversation."""

    messages = [{"role": m.role, "content": m.content} for m in request.messages]
    system = request.system_prompt + _MARKDOWN_STYLE_SUFFIX

    if request.stream:
        return StreamingResponse(
            _stream_response(
                system, messages,
                request.temperature, request.max_tokens
            ),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
            },
        )

    # Non-streaming fallback
    try:
        result = ""
        async for token in stream_chat_completion(
            system, messages, request.temperature, request.max_tokens
        ):
            if not token.startswith(_THINK_PREFIX):
                result += token
    except RuntimeError as e:
        raise HTTPException(status_code=503, detail=str(e))

    return {
        "choices": [
            {"message": {"role": "assistant", "content": result}, "finish_reason": "stop"}
        ]
    }


async def _stream_response(
    system_prompt: str,
    messages: list[dict],
    temperature: float,
    max_tokens: int,
):
    """Generate SSE stream of chat completion tokens."""
    try:
        async for token in stream_chat_completion(
            system_prompt, messages, temperature, max_tokens
        ):
            if token.startswith(_THINK_PREFIX):
                # Send thinking tokens as a separate event type
                thinking_text = token[len(_THINK_PREFIX):]
                data = json.dumps(
                    {"choices": [{"delta": {"thinking": thinking_text}, "finish_reason": None}]},
                    ensure_ascii=False,
                )
            else:
                data = json.dumps(
                    {"choices": [{"delta": {"content": token}, "finish_reason": None}]},
                    ensure_ascii=False,
                )
            yield f"data: {data}\n\n"

    except RuntimeError as e:
        error_data = json.dumps({"error": str(e)}, ensure_ascii=False)
        yield f"data: {error_data}\n\n"

    yield "data: [DONE]\n\n"
