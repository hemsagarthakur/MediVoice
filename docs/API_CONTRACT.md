# Extraction API Contract

Base path: `/api/v1`. JSON uses UTF-8 and snake_case. Maximum body size is 16 KiB; `ocr_text` is at most 12,000 characters and must contain at least eight alphanumeric characters.

## `GET /healthz`

Returns `200 {"status":"ok"}`. It does not test Groq or expose configuration.

## `POST /api/v1/extractions`

Request:

```json
{
  "schema_version": "1.0",
  "scan_mode": "prescription",
  "ocr_text": "Paracetamol 500 mg\nTake one tablet twice daily after food for 5 days"
}
```

`scan_mode` is `prescription` or `medicine_strip`. Version `1.0` is required.

Response:

```json
{
  "schema_version": "1.0",
  "request_id": "b1b299b9-4685-45c0-8cd7-9ead48640a75",
  "medicines": [
    {
      "medicine_name": "Paracetamol",
      "strength": "500 mg",
      "dose": "1 tablet",
      "frequency": "Twice daily",
      "timing": null,
      "duration": "5 days",
      "food_instruction": "After food",
      "route": null,
      "additional_instruction": null,
      "uncertain_fields": [],
      "warnings": []
    }
  ],
  "warnings": []
}
```

The response contains one to ten medicines. Empty strings, `unknown`, and `not detected` normalize to null. `uncertain_fields` contains only field identifiers from `DATA_SCHEMA.md`.

Error envelope:

```json
{
  "error": {
    "code": "invalid_model_output",
    "message": "We could not reliably read this prescription. Please retry or rescan.",
    "retryable": true,
    "request_id": "b1b299b9-4685-45c0-8cd7-9ead48640a75"
  }
}
```

Codes: `invalid_request` (400), framework validation (422), `rate_limited` (429), `no_medicine_detected` (502), `invalid_model_output` (502), `model_unavailable` (503), and `internal_error` (500). A rate-limited response includes the provider's valid `Retry-After` value when available. The server limits Groq processing to 15 seconds by default; Flutter times out the complete request after 20 seconds. Neither Flutter nor the backend silently retries rate limits.

## Demo-mode behavior

`DEMO_MODE=true` keeps this wire contract unchanged but selects deterministic extraction for known synthetic fixtures. Unsupported text returns `502 invalid_model_output`. Demo mode is never an automatic fallback: with `DEMO_MODE=false`, the backend uses Groq and a missing `GROQ_API_KEY` returns `503 model_unavailable`.

Live mode uses `GROQ_MODEL` (default `openai/gpt-oss-20b`) at `https://api.groq.com/openai/v1`. The backend first requests strict JSON Schema output without tools or function calling. Every object is closed with `additionalProperties: false`, every property is required, nullable semantic values use a string/null union, and collection/string constraints remain in the provider schema. The provider-only schema permits `medicines: []` so Groq is never forced to invent an item. Returned content is independently parsed through Pydantic; empty placeholders are removed and zero substantive medicines become a deterministic `no_medicine_detected` error. Only Groq's explicit `json_validate_failed`/`json_schema_validation_failed` HTTP 400 permits one JSON-object fallback, which is validated through the same models before conversion to the unchanged one-to-ten-medicine success payload. No other schema failure is retried. The OpenAI-compatible client has automatic retries disabled.

In development, a Groq HTTP 400 log may include its sanitized diagnostic message, type, code, and parameter. It excludes the API key, OCR text, request content, and Groq's `failed_generation` value. Pydantic rejection logs contain only validation paths and error types. Production UI and API responses never expose provider diagnostics.

## Medicine reference endpoint

`POST /api/v1/medicine-references` is separate from extraction and does not alter the extraction contract. It accepts schema version `1.0` and one to ten objects containing only `medicine_name` and `name_uncertain`. It returns one ordered reference object per request item with canonical name/RxCUI, up to three supported common-use phrases, up to four explicitly common side effects, one caution, source metadata, match quality, and availability. Uncertain, ambiguous, unmatched, or source-unavailable items return `available: false` with empty facts. Reference failure does not fail the scan.

The app must not send OCR text, images, patient data, diagnosis, prescription strength, dose, schedule, or duration to this endpoint.
