"""
LLM Gateway：支持 豆包（火山方舟） 和 Kimi Code 两种后端。
通过环境变量 LLM_PROVIDER 切换（默认 doubao）。

豆包文档:  https://www.volcengine.com/docs/82379/1298454
Kimi 文档: https://www.kimi.com/code/docs/en/more/third-party-agents.html
"""

import os
import json
import httpx
from typing import AsyncGenerator

# ── 豆包（火山方舟）常量 ────────────────────────────────────────────────────
_DOUBAO_BASE_URL = "https://ark.cn-beijing.volces.com/api/v3"
_DOUBAO_DEFAULT_MODEL = "doubao-pro-32k"

# ── Kimi Code 常量 ──────────────────────────────────────────────────────────
_KIMI_BASE_URL = "https://api.kimi.com/coding/v1"
_KIMI_DEFAULT_MODEL = "kimi-for-coding"
_KIMI_USER_AGENT = "claude-code/1.0.0"


def reset_client() -> None:
    """占位方法，保持接口兼容。"""
    pass


def _get_provider() -> str:
    return os.getenv("LLM_PROVIDER", "doubao").lower()


def _clamp_temperature(t: float) -> float:
    return max(0.0, min(1.0, t))


# ── 豆包（火山方舟）─────────────────────────────────────────────────────────

async def _stream_doubao(
    system_prompt: str,
    messages: list[dict],
    temperature: float,
    max_tokens: int,
) -> AsyncGenerator[str, None]:
    api_key = os.getenv("ARK_API_KEY", "")
    base_url = os.getenv("DOUBAO_BASE_URL", _DOUBAO_BASE_URL)
    model = os.getenv("LLM_MODEL", _DOUBAO_DEFAULT_MODEL)

    if not api_key:
        raise RuntimeError(
            "ARK_API_KEY 未配置，请在 ai-service/.env 中填写。\n"
            "前往获取: https://console.volcengine.com/ark → API Keys"
        )

    full_messages = [{"role": "system", "content": system_prompt}] + messages

    payload = {
        "model": model,
        "messages": full_messages,
        "temperature": _clamp_temperature(temperature),
        "max_tokens": max_tokens,
        "stream": True,
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    async with httpx.AsyncClient(timeout=120.0) as http:
        try:
            async with http.stream(
                "POST",
                f"{base_url}/chat/completions",
                json=payload,
                headers=headers,
            ) as response:
                if response.status_code == 401:
                    raise RuntimeError(
                        "豆包 API 认证失败（401）：请检查 ARK_API_KEY 是否正确"
                    )
                if response.status_code == 403:
                    raise RuntimeError(
                        "豆包 API 访问被拒绝（403）：请确认 API Key 有效且模型已开通"
                    )
                if response.status_code == 429:
                    raise RuntimeError("豆包 API 请求频率超限（429），请稍后再试")
                if response.status_code != 200:
                    body = await response.aread()
                    raise RuntimeError(
                        f"豆包 API 错误 {response.status_code}: {body.decode()}"
                    )

                async for line in response.aiter_lines():
                    if not line.startswith("data:"):
                        continue
                    data_str = line[5:].strip()
                    if data_str == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data_str)
                    except json.JSONDecodeError:
                        continue

                    if chunk.get("error"):
                        raise RuntimeError(
                            chunk["error"].get("message", "豆包 API 错误")
                        )

                    choices = chunk.get("choices", [])
                    if not choices:
                        continue
                    delta = choices[0].get("delta", {})

                    # reasoning_content：部分豆包模型（如 doubao-thinking）支持
                    reasoning = delta.get("reasoning_content")
                    if reasoning:
                        yield f"\x00think\x00{reasoning}"

                    content = delta.get("content")
                    if content:
                        yield content

        except httpx.RequestError as e:
            raise RuntimeError(f"无法连接到豆包 API: {e}") from e


# ── Kimi Code ────────────────────────────────────────────────────────────────

async def _stream_kimi(
    system_prompt: str,
    messages: list[dict],
    temperature: float,
    max_tokens: int,
) -> AsyncGenerator[str, None]:
    api_key = os.getenv("KIMI_CODE_API_KEY", "")
    base_url = os.getenv("KIMI_CODE_BASE_URL", _KIMI_BASE_URL)
    model = os.getenv("LLM_MODEL", _KIMI_DEFAULT_MODEL)

    if not api_key:
        raise RuntimeError(
            "KIMI_CODE_API_KEY 未配置，请在 ai-service/.env 中填写。\n"
            "前往获取: https://www.kimi.com/code → 会员页面 → API Keys"
        )

    full_messages = [{"role": "system", "content": system_prompt}] + messages

    payload = {
        "model": model,
        "messages": full_messages,
        "temperature": _clamp_temperature(temperature),
        "max_tokens": max_tokens,
        "stream": True,
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "User-Agent": _KIMI_USER_AGENT,
    }

    async with httpx.AsyncClient(timeout=120.0) as http:
        try:
            async with http.stream(
                "POST",
                f"{base_url}/chat/completions",
                json=payload,
                headers=headers,
            ) as response:
                if response.status_code == 401:
                    raise RuntimeError(
                        "Kimi Code API 认证失败（401）：请检查 KIMI_CODE_API_KEY"
                    )
                if response.status_code == 403:
                    raise RuntimeError(
                        "Kimi Code API 访问被拒绝（403）：请确认已订阅 Kimi Code 会员"
                    )
                if response.status_code == 429:
                    raise RuntimeError("Kimi Code API 请求频率超限（429），请稍后再试")
                if response.status_code != 200:
                    body = await response.aread()
                    raise RuntimeError(
                        f"Kimi Code API 错误 {response.status_code}: {body.decode()}"
                    )

                async for line in response.aiter_lines():
                    if not line.startswith("data:"):
                        continue
                    data_str = line[5:].strip()
                    if data_str == "[DONE]":
                        break
                    try:
                        chunk = json.loads(data_str)
                    except json.JSONDecodeError:
                        continue

                    if chunk.get("error"):
                        raise RuntimeError(
                            chunk["error"].get("message", "Kimi Code API 错误")
                        )

                    choices = chunk.get("choices", [])
                    if not choices:
                        continue
                    delta = choices[0].get("delta", {})

                    reasoning = delta.get("reasoning_content")
                    if reasoning:
                        yield f"\x00think\x00{reasoning}"

                    content = delta.get("content")
                    if content:
                        yield content

        except httpx.RequestError as e:
            raise RuntimeError(f"无法连接到 Kimi Code API: {e}") from e


# ── 统一入口 ─────────────────────────────────────────────────────────────────

async def stream_chat_completion(
    system_prompt: str,
    messages: list[dict],
    temperature: float = 0.7,
    max_tokens: int = 32768,
) -> AsyncGenerator[str, None]:
    """
    流式调用 LLM（豆包或 Kimi，由 LLM_PROVIDER 决定）。

    Yields:
        普通 token:   直接 yield 文本字符串
        思考 token:   yield "\\x00think\\x00{text}"
    """
    provider = _get_provider()
    if provider == "kimi":
        async for token in _stream_kimi(system_prompt, messages, temperature, max_tokens):
            yield token
    else:
        async for token in _stream_doubao(system_prompt, messages, temperature, max_tokens):
            yield token


async def get_chat_completion(
    system_prompt: str,
    messages: list[dict],
    temperature: float = 0.3,
    max_tokens: int = 4096,
) -> str:
    """非流式调用（用于内部任务，如记忆提取）。"""
    result = ""
    async for token in stream_chat_completion(
        system_prompt, messages, temperature, max_tokens
    ):
        if not token.startswith("\x00think\x00"):
            result += token
    return result
