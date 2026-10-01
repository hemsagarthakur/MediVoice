import asyncio
import logging
import time
from collections.abc import Awaitable, Callable
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from backend.app.config import get_settings
from backend.app.errors import GeminiServiceError
from backend.app.gemini_service import GeminiExtractionService
from backend.app.mock_extraction_service import MockExtractionService
from backend.app.models import (
    ApiErrorDetail,
    ApiErrorResponse,
    ExtractionRequest,
    ExtractionResponse,
)
from backend.app.safety import apply_deterministic_safety

MAX_BODY_BYTES = 16 * 1024
settings = get_settings()
logging.basicConfig(level=getattr(logging, settings.log_level.upper(), logging.INFO))
logger = logging.getLogger("medivoice.api")

app = FastAPI(
    title="MediVoice Extraction API",
    version="1.0.0",
    docs_url="/docs" if settings.app_env != "production" else None,
    redoc_url=None,
)


def error_response(
    *, request_id: str, code: str, message: str, retryable: bool, status_code: int
) -> JSONResponse:
    body = ApiErrorResponse(
        error=ApiErrorDetail(
            code=code,
            message=message,
            retryable=retryable,
            request_id=request_id,
        )
    )
    return JSONResponse(status_code=status_code, content=body.model_dump(mode="json"))


@app.middleware("http")
async def limit_body_size(
    request: Request,
    call_next: Callable[[Request], Awaitable[JSONResponse]],
):
    request_id = request.headers.get("x-request-id") or str(uuid4())
    request.state.request_id = request_id
    content_length = request.headers.get("content-length")
    try:
        body_too_large = bool(content_length) and int(content_length) > MAX_BODY_BYTES
    except ValueError:
        body_too_large = True
    if body_too_large:
        return error_response(
            request_id=request_id,
            code="invalid_request",
            message="The extracted text is too large to process.",
            retryable=False,
            status_code=400,
        )
    response = await call_next(request)
    response.headers["x-request-id"] = request_id
    return response


@app.exception_handler(RequestValidationError)
async def validation_error_handler(
    request: Request, error: RequestValidationError
) -> JSONResponse:
    content_error = any(
        issue.get("loc", ())[-1:] in {("scan_mode",), ("ocr_text",)}
        and issue.get("type") != "missing"
        for issue in error.errors()
    )
    return error_response(
        request_id=request.state.request_id,
        code="invalid_request",
        message="The extraction request is invalid.",
        retryable=False,
        status_code=400 if content_error else 422,
    )


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.post(
    "/api/v1/extractions",
    response_model=ExtractionResponse,
    responses={400: {"model": ApiErrorResponse}, 502: {"model": ApiErrorResponse}},
)
async def create_extraction(
    payload: ExtractionRequest,
    request: Request,
) -> ExtractionResponse | JSONResponse:
    request_id = request.state.request_id
    started = time.monotonic()
    service = MockExtractionService() if settings.demo_mode else GeminiExtractionService(settings)
    try:
        extracted = await asyncio.wait_for(
            asyncio.to_thread(service.extract, payload.scan_mode, payload.ocr_text),
            timeout=settings.api_request_timeout_seconds,
        )
        safe_payload = apply_deterministic_safety(extracted, payload.scan_mode)
        logger.info(
            "extraction_success request_id=%s mode=%s ocr_chars=%d medicines=%d elapsed_ms=%d",
            request_id,
            payload.scan_mode.value,
            len(payload.ocr_text),
            len(safe_payload.medicines),
            int((time.monotonic() - started) * 1000),
        )
        return ExtractionResponse(
            request_id=request_id,
            medicines=safe_payload.medicines,
            warnings=safe_payload.warnings,
        )
    except TimeoutError:
        code = "model_unavailable"
        logger.warning("extraction_failure request_id=%s code=%s", request_id, code)
        return error_response(
            request_id=request_id,
            code=code,
            message="The extraction service timed out. Please retry.",
            retryable=True,
            status_code=503,
        )
    except GeminiServiceError as error:
        logger.warning(
            "extraction_failure request_id=%s code=%s", request_id, error.code
        )
        return error_response(
            request_id=request_id,
            code=error.code,
            message=error.message,
            retryable=error.retryable,
            status_code=error.status_code,
        )
    except Exception:
        logger.error("extraction_failure request_id=%s code=internal_error", request_id)
        return error_response(
            request_id=request_id,
            code="internal_error",
            message="The extraction service failed safely. Please retry.",
            retryable=True,
            status_code=500,
        )
