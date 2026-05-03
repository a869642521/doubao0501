import json
from .llm_gateway import get_chat_completion

EXTRACT_PROMPT = """请从以下对话中提取关键记忆信息。返回 JSON 数组，每个元素包含：
- content: 记忆内容（简洁的一句话）
- level: 记忆等级（"L2_SHORT_TERM" 表示短期记忆，"L3_LONG_TERM" 表示重要的长期记忆）
- metadata: 额外信息（如话题标签）

只提取有意义的信息（用户偏好、重要事件、情感表达等），忽略无关闲聊。
如果没有有意义的记忆，返回空数组 []。
只返回 JSON，不要有其他文字。"""


async def extract_memories(messages: list[dict]) -> list[dict]:
    """Extract memorable information from a conversation."""
    conversation_text = "\n".join(
        f"{m['role']}: {m['content']}" for m in messages
    )

    result = await get_chat_completion(
        system_prompt="你是一个记忆提取助手。只返回JSON格式。",
        messages=[{
            "role": "user",
            "content": f"{EXTRACT_PROMPT}\n\n对话内容：\n{conversation_text}",
        }],
        temperature=0.3,
        max_tokens=512,
    )

    try:
        result = result.strip()
        if result.startswith("```"):
            result = result.split("\n", 1)[1].rsplit("```", 1)[0]
        memories = json.loads(result)
        return memories if isinstance(memories, list) else []
    except (json.JSONDecodeError, IndexError):
        return []
