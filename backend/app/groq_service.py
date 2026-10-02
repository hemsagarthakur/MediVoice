from collections.abc import Callable
from copy import deepcopy
import json
import logging
import re
from typing import Any, NoReturn

from openai import OpenAI
from pydantic import ValidationError

from backend.app.config import Settings
from backend.app.errors import (
    InvalidModelOutputError,
    NoMedicineDetectedError,
    ProviderServiceError,
)
from backend.app.models import (
    ExtractionPayload,
    MedicineInstruction,
    ProviderExtractionPayload,
    ScanMode,
)
from backend.app.prompt import build_prompt


GROQ_BASE_URL = "https://api.groq.com/openai/v1"
MAX_COMPLETION_TOKENS = 4096
logger = logging.getLogger("medivoice.groq")

FALLBACK_OUTPUT_INSTRUCTIONS = """
The provider could not enforce the strict schema for this request. Return one JSON object only.
The object must contain `medicines` and `warnings`. `medicines` may be an empty array when no named medicine is confidently detected. `warnings` must be an array and may be empty.
Every medicine object must use exactly these keys: medicine_name, strength, dose, frequency, timing, duration, food_instruction, route, additional_instruction, uncertain_fields, warnings.
Use null for every absent semantic field and an empty array for absent uncertainty or warnings. Do not add, infer, or repair unsupported medicine information.
""".strip()


def _is_development(settings: Settings) -> bool:
    return settings.app_env.casefold() != "production"


def _safe_provider_error_body(error: Exception, *, secrets: tuple[str, ...]) -> str:
    """Return useful Groq diagnostics without request or generated patient content."""
    body = getattr(error, "body", None)
    if isinstance(body, dict):
        provider_error = body.get("error", body)
        if isinstance(provider_error, dict):
            # Groq can attach `failed_generation` to structured-output errors. It may
            # contain extracted prescription fields, so only retain diagnostic keys.
            body = {
                key: provider_error[key]
                for key in ("message", "type", "code", "param")
                if key in provider_error
                and isinstance(provider_error[key], (str, int, float, bool, type(None)))
            }
    rendered = json.dumps(body, default=str, ensure_ascii=True) if body else str(error)
    for secret in secrets:
        if secret:
            rendered = rendered.replace(secret, "[REDACTED]")
    rendered = re.sub(r"\b(?:gsk|sk)_[A-Za-z0-9_-]+", "[REDACTED]", rendered)
    return rendered[:4000]


def _validation_issue_summary(error: ValidationError) -> str:
    issues = [
        {
            "path": ".".join(str(part) for part in issue.get("loc", ())) or "$",
            "type": issue.get("type", "validation_error"),
        }
        for issue in error.errors(
            include_url=False,
            include_context=False,
            include_input=False,
        )
    ]
    return json.dumps(issues, separators=(",", ":"), ensure_ascii=True)


def _provider_error_code(error: Exception) -> str | None:
    body = getattr(error, "body", None)
    if not isinstance(body, dict):
        return None
    provider_error = body.get("error", body)
    if not isinstance(provider_error, dict):
        return None
    code = provider_error.get("code")
    return code if isinstance(code, str) else None


def _retry_after_header(error: Exception) -> str | None:
    response = getattr(error, "response", None)
    headers = getattr(response, "headers", None) or getattr(error, "headers", None)
    if headers is None or not hasattr(headers, "get"):
        return None
    value = headers.get("retry-after") or headers.get("Retry-After")
    if value is None:
        return None
    rendered = str(value).strip()
    if not rendered or len(rendered) > 128 or "\r" in rendered or "\n" in rendered:
        return None
    return rendered


def _is_json_schema_failure(error: Exception) -> bool:
    return getattr(error, "status_code", None) == 400 and _provider_error_code(
        error
    ) in {"json_validate_failed", "json_schema_validation_failed"}


def _has_extracted_content(medicine: MedicineInstruction) -> bool:
    return any(
        (
            medicine.medicine_name,
            medicine.strength,
            medicine.dose,
            medicine.frequency,
            medicine.timing,
            medicine.duration,
            medicine.food_instruction,
            medicine.route,
            medicine.additional_instruction,
            medicine.uncertain_fields,
            medicine.warnings,
        )
    )


def _finalize_provider_payload(
    payload: ProviderExtractionPayload,
) -> ExtractionPayload:
    """Drop empty provider items and enforce the unchanged success contract."""
    medicines = [
        medicine for medicine in payload.medicines if _has_extracted_content(medicine)
    ]
    if not medicines:
        raise NoMedicineDetectedError()
    return ExtractionPayload(medicines=medicines, warnings=payload.warnings)


def strict_extraction_schema() -> dict[str, Any]:
    """Convert the Pydantic schema to Groq's strict-output requirements.

    The conversion removes presentation/default metadata only. Validation
    constraints from ``ProviderExtractionPayload`` remain intact. The provider
    may return an empty list; successful API responses still require at least
    one medicine through ``ExtractionPayload``.
    """
    schema = deepcopy(ProviderExtractionPayload.model_json_schema())

    def normalize(node: Any) -> None:
        if isinstance(node, list):
            for item in node:
                normalize(item)
            return
        if not isinstance(node, dict):
            return

        node.pop("default", None)
        node.pop("title", None)

        # Pydantic emits nullable strings as anyOf(string, null). Groq's strict
        # examples use a required key whose type is the nullable union.
        alternatives = node.get("anyOf")
        if isinstance(alternatives, list) and len(alternatives) == 2:
            string_schema = next(
                (
                    option
                    for option in alternatives
                    if isinstance(option, dict) and option.get("type") == "string"
                ),
                None,
            )
            has_null = any(
                isinstance(option, dict) and option.get("type") == "null"
                for option in alternatives
            )
            if string_schema is not None and has_null:
                node.pop("anyOf")
                node.update(string_schema)
                node["type"] = ["string", "null"]

        for value in node.values():
            normalize(value)
        if node.get("type") == "object":
            properties = node.get("properties", {})
            node["required"] = list(properties)
            node["additionalProperties"] = False

    normalize(schema)
    return schema


class GroqExtractionService:
    def __init__(
        self,
        settings: Settings,
        *,
        client_factory: Callable[..., Any] | None = None,
    ) -> None:
        self._settings = settings
        self._client_factory = client_factory or OpenAI

    def extract(self, mode: ScanMode, ocr_text: str) -> ExtractionPayload:
        if not self._settings.groq_api_key:
            raise ProviderServiceError(
                "model_unavailable",
                "Medicine extraction is not configured. Please try again later.",
                retryable=True,
                status_code=503,
            )

        client = self._client_factory(
            api_key=self._settings.groq_api_key,
            base_url=GROQ_BASE_URL,
            timeout=self._settings.api_request_timeout_seconds,
            max_retries=0,
        )
        prompt = build_prompt(mode, ocr_text)
        try:
            response = self._create_completion(
                client,
                prompt,
                response_format={
                    "type": "json_schema",
                    "json_schema": {
                        "name": "medicine_extraction",
                        "strict": True,
                        "schema": strict_extraction_schema(),
                    },
                },
            )
        except Exception as error:
            if not _is_json_schema_failure(error):
                self._raise_provider_error(error, ocr_text)
            self._log_http_400(error, ocr_text)
            logger.warning(
                "groq_strict_schema_fallback code=%s",
                _provider_error_code(error),
            )
            try:
                response = self._create_completion(
                    client,
                    f"{prompt}\n\n{FALLBACK_OUTPUT_INSTRUCTIONS}",
                    response_format={"type": "json_object"},
                )
            except Exception as fallback_error:
                self._raise_provider_error(fallback_error, ocr_text)

        return self._validate_response(response)

    def _create_completion(
        self,
        client: Any,
        prompt: str,
        *,
        response_format: dict[str, Any],
    ) -> Any:
        return client.chat.completions.create(
            model=self._settings.groq_model,
            messages=[{"role": "user", "content": prompt}],
            temperature=0,
            reasoning_effort="low",
            max_completion_tokens=MAX_COMPLETION_TOKENS,
            response_format=response_format,
            stream=False,
        )

    def _validate_response(self, response: Any) -> ExtractionPayload:
        if not response.choices:
            if _is_development(self._settings):
                logger.warning(
                    "groq_invalid_model_output issues=%s",
                    '[{"path":"response.choices","type":"missing"}]',
                )
            raise InvalidModelOutputError()
        content = response.choices[0].message.content
        if not isinstance(content, str) or not content.strip():
            if _is_development(self._settings):
                logger.warning(
                    "groq_invalid_model_output issues=%s",
                    '[{"path":"response.choices.0.message.content",'
                    '"type":"missing_or_blank"}]',
                )
            raise InvalidModelOutputError()
        try:
            validated = ProviderExtractionPayload.model_validate_json(content)
        except ValidationError as error:
            if _is_development(self._settings):
                logger.warning(
                    "groq_invalid_model_output issues=%s",
                    _validation_issue_summary(error),
                )
            raise InvalidModelOutputError() from error
        try:
            return _finalize_provider_payload(validated)
        except NoMedicineDetectedError:
            if _is_development(self._settings):
                logger.warning(
                    "groq_no_medicine_detected issues=%s",
                    '[{"path":"medicines","type":"no_substantive_items"}]',
                )
            raise

    def _log_http_400(self, error: Exception, ocr_text: str) -> None:
        if _is_development(self._settings):
            logger.warning(
                "groq_http_error status=400 body=%s",
                _safe_provider_error_body(
                    error,
                    secrets=(self._settings.groq_api_key, ocr_text),
                ),
            )

    def _raise_provider_error(self, error: Exception, ocr_text: str) -> NoReturn:
        status_code = getattr(error, "status_code", None)
        if status_code == 400:
            self._log_http_400(error, ocr_text)
        if _is_json_schema_failure(error):
            raise InvalidModelOutputError() from error
        if status_code == 429:
            raise ProviderServiceError(
                "rate_limited",
                "The extraction service is temporarily rate limited. Please wait and retry.",
                retryable=True,
                status_code=429,
                retry_after=_retry_after_header(error),
            ) from error
        raise ProviderServiceError(
            "model_unavailable",
            "We could not reach the extraction service. Please retry.",
            retryable=True,
            status_code=503,
        ) from error
