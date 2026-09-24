"""ProfessorOS – Provider-agnostic LLM configuration layer and client factory.

Supports OpenAI-compatible /v1/chat/completions endpoints across:
  - Primary: Groq (free tier, ultra-fast LPU inference)
  - Fallback: OpenRouter (automatic failover on HTTP 429 or provider errors)
  - Future local migration: Ollama / vLLM (via LLM_BASE_URL in .env)

No vendor-locked SDKs. Built entirely on standard HTTP protocol via httpx.
"""

import json
import logging
from enum import Enum
from typing import Any, Dict, List, Optional, Type, TypeVar, Union
import httpx
from pydantic import BaseModel, ValidationError

logger = logging.getLogger("professor_os.llm")

T = TypeVar("T", bound=BaseModel)


class LLMPipeline(str, Enum):
    """Supported specialized LLM pipelines across ProfessorOS."""
    GRADING = "grading"              # Accuracy critical (DeepSeek-R1-Distill-70B)
    RAG = "rag"                      # Speed + doc faithfulness (IBM Granite 3.1 8B Instruct)
    QUESTION_GEN = "question_gen"    # Quality + structure (Llama-3.3-70B-Versatile)


class LLMProvider(str, Enum):
    """Underlying inference providers."""
    LOCAL_OVERRIDE = "local_override"
    GROQ = "groq"
    OPENROUTER = "openrouter"


class LLMConfigError(Exception):
    """Raised when LLM configuration or call fails across all providers."""
    pass


class LLMRateLimitError(LLMConfigError):
    """Raised when rate limit (HTTP 429) is encountered."""
    pass


class PipelineSpec(BaseModel):
    """Specification of models and routing for a given pipeline."""
    pipeline: LLMPipeline
    primary_model: str
    fallback_model: str
    temperature: float = 0.2
    max_tokens: int = 4096


class LLMClient:
    """Unified HTTP-based client that executes OpenAI-compatible completions

    with automatic rate-limit failover between primary (Groq) and fallback (OpenRouter).
    """

    def __init__(self, settings_obj: Optional[Any] = None):
        """Initializes client using settings or dynamic configuration."""
        if settings_obj is None:
            from app.config.settings import get_settings
            self.settings = get_settings()
        else:
            self.settings = settings_obj

        # Pipeline catalog
        grading_primary = (
            getattr(self.settings, "GRADING_MODEL_DEV", None)
            or getattr(self.settings, "MODEL_GRADING_PRIMARY", "deepseek-r1-distill-llama-70b")
        )

        self.pipelines: Dict[LLMPipeline, PipelineSpec] = {
            LLMPipeline.GRADING: PipelineSpec(
                pipeline=LLMPipeline.GRADING,
                primary_model=grading_primary,
                fallback_model=getattr(self.settings, "MODEL_GRADING_FALLBACK", "deepseek/deepseek-r1-distill-llama-70b"),
                temperature=0.1,  # Low temperature for deterministic, rubric-faithful scoring
                max_tokens=2048,
            ),
            LLMPipeline.RAG: PipelineSpec(
                pipeline=LLMPipeline.RAG,
                primary_model=getattr(self.settings, "MODEL_RAG_PRIMARY", "llama-3.1-8b-instant"),
                fallback_model=getattr(self.settings, "MODEL_RAG_FALLBACK", "meta-llama/llama-3.1-8b-instruct"),
                temperature=0.2,
                max_tokens=1024,
            ),
            LLMPipeline.QUESTION_GEN: PipelineSpec(
                pipeline=LLMPipeline.QUESTION_GEN,
                primary_model=getattr(self.settings, "MODEL_QUESTION_GEN_PRIMARY", "llama-3.3-70b-versatile"),
                fallback_model=getattr(self.settings, "MODEL_QUESTION_GEN_FALLBACK", "meta-llama/llama-3.3-70b-instruct"),
                temperature=0.4,  # Moderate temperature for creative distractors while maintaining Bloom alignment
                max_tokens=4096,
            ),
        }

        # Timeouts (seconds)
        self.timeout = httpx.Timeout(connect=15.0, read=90.0, write=20.0, pool=15.0)

    def _get_provider_endpoint(self, provider: LLMProvider) -> Dict[str, str]:
        """Resolves base URL and authorization headers for the given provider."""
        # 1. Local Hardware Override (Ollama / vLLM / Local AI box)
        local_base = getattr(self.settings, "LLM_BASE_URL", None)
        if local_base:
            api_key = getattr(self.settings, "LLM_API_KEY", "ollama") or "ollama"
            clean_base = local_base.rstrip("/")
            url = f"{clean_base}/chat/completions" if not clean_base.endswith("/chat/completions") else clean_base
            return {
                "url": url,
                "api_key": api_key,
                "provider": LLMProvider.LOCAL_OVERRIDE.value,
            }

        # 2. Groq (Primary Cloud)
        if provider == LLMProvider.GROQ:
            base = getattr(self.settings, "GROQ_BASE_URL", "https://api.groq.com/openai/v1").rstrip("/")
            url = f"{base}/chat/completions" if not base.endswith("/chat/completions") else base
            api_key = getattr(self.settings, "GROQ_API_KEY", "")
            return {"url": url, "api_key": api_key, "provider": LLMProvider.GROQ.value}

        # 3. OpenRouter (Fallback Cloud)
        if provider == LLMProvider.OPENROUTER:
            base = getattr(self.settings, "OPENROUTER_BASE_URL", "https://openrouter.ai/api/v1").rstrip("/")
            url = f"{base}/chat/completions" if not base.endswith("/chat/completions") else base
            api_key = getattr(self.settings, "OPENROUTER_API_KEY", "")
            return {"url": url, "api_key": api_key, "provider": LLMProvider.OPENROUTER.value}

        raise LLMConfigError(f"Unsupported provider: {provider}")

    def _build_request_payload(
        self,
        model_name: str,
        messages: List[Dict[str, str]],
        temperature: float,
        max_tokens: int,
        json_mode: bool = False,
    ) -> Dict[str, Any]:
        """Constructs the standard OpenAI-compliant completion request payload."""
        payload: Dict[str, Any] = {
            "model": model_name,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens,
        }
        if json_mode:
            payload["response_format"] = {"type": "json_object"}
            # Groq API requirement: messages must contain the word 'json' when response_format is json_object
            has_json = any("json" in str(m.get("content", "")).lower() for m in messages)
            if not has_json and messages:
                messages = list(messages)
                messages[0] = {
                    **messages[0],
                    "content": messages[0]["content"] + "\nYou must format your entire response as a valid JSON object.",
                }
                payload["messages"] = messages
        return payload

    def _execute_http_post(
        self,
        endpoint_info: Dict[str, str],
        payload: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Executes a synchronous HTTP POST with strict status code handling."""
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {endpoint_info['api_key']}",
        }
        if endpoint_info["provider"] == LLMProvider.OPENROUTER.value:
            headers["HTTP-Referer"] = "https://professor-os.edu.pk"
            headers["X-Title"] = "ProfessorOS Academic Suite"

        with httpx.Client(timeout=self.timeout) as client:
            response = client.post(endpoint_info["url"], json=payload, headers=headers)

        if response.status_code == 429:
            raise LLMRateLimitError(f"Rate limit exceeded (HTTP 429) on {endpoint_info['provider']}: {response.text}")
        if response.status_code >= 400:
            raise LLMConfigError(
                f"HTTP {response.status_code} from {endpoint_info['provider']}: {response.text}"
            )

        return response.json()

    async def _execute_async_http_post(
        self,
        endpoint_info: Dict[str, str],
        payload: Dict[str, Any],
    ) -> Dict[str, Any]:
        """Executes an asynchronous HTTP POST with strict status code handling."""
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {endpoint_info['api_key']}",
        }
        if endpoint_info["provider"] == LLMProvider.OPENROUTER.value:
            headers["HTTP-Referer"] = "https://professor-os.edu.pk"
            headers["X-Title"] = "ProfessorOS Academic Suite"

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(endpoint_info["url"], json=payload, headers=headers)

        if response.status_code == 429:
            raise LLMRateLimitError(f"Rate limit exceeded (HTTP 429) on {endpoint_info['provider']}: {response.text}")
        if response.status_code >= 400:
            raise LLMConfigError(
                f"HTTP {response.status_code} from {endpoint_info['provider']}: {response.text}"
            )

        return response.json()

    def complete(
        self,
        pipeline: LLMPipeline,
        messages: List[Dict[str, str]],
        json_mode: bool = False,
        temperature: Optional[float] = None,
        max_tokens: Optional[float] = None,
    ) -> str:
        """Synchronous chat completion with automatic Groq -> OpenRouter failover."""
        spec = self.pipelines[pipeline]
        temp = temperature if temperature is not None else spec.temperature
        tokens = int(max_tokens if max_tokens is not None else spec.max_tokens)

        # Check for local override
        if getattr(self.settings, "LLM_BASE_URL", None):
            endpoint = self._get_provider_endpoint(LLMProvider.LOCAL_OVERRIDE)
            payload = self._build_request_payload(spec.primary_model, messages, temp, tokens, json_mode)
            logger.info("Executing LLM pipeline '%s' via LOCAL OVERRIDE (%s)", pipeline.value, endpoint["url"])
            res = self._execute_http_post(endpoint, payload)
            return res["choices"][0]["message"]["content"]

        # Primary attempt (Groq)
        try:
            endpoint = self._get_provider_endpoint(LLMProvider.GROQ)
            payload = self._build_request_payload(spec.primary_model, messages, temp, tokens, json_mode)
            logger.debug("Dispatching to Primary Provider (Groq: %s) for pipeline '%s'", spec.primary_model, pipeline.value)
            res = self._execute_http_post(endpoint, payload)
            return res["choices"][0]["message"]["content"]

        except (LLMRateLimitError, httpx.HTTPError, LLMConfigError) as err:
            logger.warning(
                "Primary provider (Groq) failed for pipeline '%s' with error: %s. Initiating OpenRouter fallback...",
                pipeline.value,
                err,
            )

            # Fallback attempt (OpenRouter)
            try:
                fallback_endpoint = self._get_provider_endpoint(LLMProvider.OPENROUTER)
                fallback_payload = self._build_request_payload(spec.fallback_model, messages, temp, tokens, json_mode)
                logger.info(
                    "Failover successful: Dispatching to Fallback Provider (OpenRouter: %s) for pipeline '%s'",
                    spec.fallback_model,
                    pipeline.value,
                )
                res = self._execute_http_post(fallback_endpoint, fallback_payload)
                return res["choices"][0]["message"]["content"]
            except Exception as fb_err:
                logger.error("Both primary (Groq) and fallback (OpenRouter) providers failed for pipeline '%s'", pipeline.value)
                raise LLMConfigError(f"All LLM providers failed for {pipeline.value}: Primary err: {err}, Fallback err: {fb_err}") from fb_err

    async def acomplete(
        self,
        pipeline: LLMPipeline,
        messages: List[Dict[str, str]],
        json_mode: bool = False,
        temperature: Optional[float] = None,
        max_tokens: Optional[float] = None,
    ) -> str:
        """Asynchronous chat completion with automatic Groq -> OpenRouter failover."""
        spec = self.pipelines[pipeline]
        temp = temperature if temperature is not None else spec.temperature
        tokens = int(max_tokens if max_tokens is not None else spec.max_tokens)

        # Check for local override
        if getattr(self.settings, "LLM_BASE_URL", None):
            endpoint = self._get_provider_endpoint(LLMProvider.LOCAL_OVERRIDE)
            payload = self._build_request_payload(spec.primary_model, messages, temp, tokens, json_mode)
            res = await self._execute_async_http_post(endpoint, payload)
            return res["choices"][0]["message"]["content"]

        # Primary attempt (Groq)
        try:
            endpoint = self._get_provider_endpoint(LLMProvider.GROQ)
            payload = self._build_request_payload(spec.primary_model, messages, temp, tokens, json_mode)
            res = await self._execute_async_http_post(endpoint, payload)
            return res["choices"][0]["message"]["content"]

        except (LLMRateLimitError, httpx.HTTPError, LLMConfigError) as err:
            logger.warning(
                "Async Primary provider (Groq) failed for pipeline '%s' with error: %s. Initiating OpenRouter fallback...",
                pipeline.value,
                err,
            )

            # Fallback attempt (OpenRouter)
            try:
                fallback_endpoint = self._get_provider_endpoint(LLMProvider.OPENROUTER)
                fallback_payload = self._build_request_payload(spec.fallback_model, messages, temp, tokens, json_mode)
                res = await self._execute_async_http_post(fallback_endpoint, fallback_payload)
                return res["choices"][0]["message"]["content"]
            except Exception as fb_err:
                logger.error("Both primary (Groq) and fallback (OpenRouter) providers failed in async call for '%s'", pipeline.value)
                raise LLMConfigError(f"All LLM providers failed for {pipeline.value}: Primary: {err}, Fallback: {fb_err}") from fb_err

    def complete_structured(
        self,
        pipeline: LLMPipeline,
        messages: List[Dict[str, str]],
        response_model: Type[T],
        temperature: Optional[float] = None,
        max_tokens: Optional[float] = None,
    ) -> T:
        """Executes completion, requiring output to strictly validate against a Pydantic schema."""
        raw_text = self.complete(
            pipeline=pipeline,
            messages=messages,
            json_mode=True,
            temperature=temperature,
            max_tokens=max_tokens,
        )

        try:
            # Strip potential markdown code fences if model accidentally wrapped output
            cleaned = raw_text.strip()
            if cleaned.startswith("```json"):
                cleaned = cleaned[7:]
            if cleaned.startswith("```"):
                cleaned = cleaned[3:]
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3]
            cleaned = cleaned.strip()

            parsed_data = json.loads(cleaned)
            if isinstance(parsed_data, list):
                parsed_data = {"questions": parsed_data}
            return response_model.model_validate(parsed_data)
        except (json.JSONDecodeError, ValidationError) as e:
            logger.error("Failed to parse structured response from pipeline '%s': %s\nRaw output: %s", pipeline.value, e, raw_text)
            raise LLMConfigError(f"Model response did not match schema {response_model.__name__}: {e}") from e

    async def acomplete_structured(
        self,
        pipeline: LLMPipeline,
        messages: List[Dict[str, str]],
        response_model: Type[T],
        temperature: Optional[float] = None,
        max_tokens: Optional[float] = None,
    ) -> T:
        """Async variant of complete_structured."""
        raw_text = await self.acomplete(
            pipeline=pipeline,
            messages=messages,
            json_mode=True,
            temperature=temperature,
            max_tokens=max_tokens,
        )

        try:
            cleaned = raw_text.strip()
            if cleaned.startswith("```json"):
                cleaned = cleaned[7:]
            if cleaned.startswith("```"):
                cleaned = cleaned[3:]
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3]
            cleaned = cleaned.strip()

            parsed_data = json.loads(cleaned)
            if isinstance(parsed_data, list):
                parsed_data = {"questions": parsed_data}
            return response_model.model_validate(parsed_data)
        except (json.JSONDecodeError, ValidationError) as e:
            logger.error("Async structured parse failed for pipeline '%s': %s\nRaw: %s", pipeline.value, e, raw_text)
            raise LLMConfigError(f"Model response did not match schema {response_model.__name__}: {e}") from e


# Singleton factory instance
_llm_client_instance: Optional[LLMClient] = None


def get_llm_client() -> LLMClient:
    """Returns singleton instance of the LLM Client."""
    global _llm_client_instance
    if _llm_client_instance is None:
        _llm_client_instance = LLMClient()
    return _llm_client_instance
