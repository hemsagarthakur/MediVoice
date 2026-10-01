from collections.abc import Callable
from typing import Any

from pydantic import ValidationError

from backend.app.config import Settings
from backend.app.errors import GeminiServiceError, InvalidModelOutputError
from backend.app.models import ExtractionPayload, ScanMode
from backend.app.prompt import build_prompt


class GeminiExtractionService:
    def __init__(
        self,
        settings: Settings,
        *,
        client_factory: Callable[..., Any] | None = None,
    ) -> None:
        self._settings = settings
        self._client_factory = client_factory

    def extract(self, mode: ScanMode, ocr_text: str) -> ExtractionPayload:
        if not self._settings.gemini_api_key:
            raise GeminiServiceError(
                "model_unavailable",
                "Medicine extraction is not configured. Please try again later.",
                retryable=True,
                status_code=503,
            )

        try:
            from google import genai
            from google.genai import types

            factory = self._client_factory or genai.Client
            with factory(api_key=self._settings.gemini_api_key) as client:
                response = client.models.generate_content(
                    model=self._settings.gemini_model,
                    contents=build_prompt(mode, ocr_text),
                    config=types.GenerateContentConfig(
                        temperature=0,
                        max_output_tokens=2048,
                        response_mime_type="application/json",
                        response_schema=ExtractionPayload,
                    ),
                )

            if isinstance(response.parsed, ExtractionPayload):
                return response.parsed
            if response.text:
                return ExtractionPayload.model_validate_json(response.text)
            raise InvalidModelOutputError()
        except InvalidModelOutputError:
            raise
        except ValidationError as error:
            raise InvalidModelOutputError() from error
        except Exception as error:
            status_code = getattr(error, "status_code", None) or getattr(
                error, "code", None
            )
            if status_code == 429:
                raise GeminiServiceError(
                    "rate_limited",
                    "The extraction service is busy. Please wait and retry.",
                    retryable=True,
                    status_code=429,
                ) from error
            raise GeminiServiceError(
                "model_unavailable",
                "We could not reach the extraction service. Please retry.",
                retryable=True,
                status_code=503,
            ) from error

