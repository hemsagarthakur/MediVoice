# Extraction API Contract

Base path: `/api/v1`. JSON uses UTF-8 and snake_case. Maximum body size is 16 KiB; `ocr_text` is at most 12,000 characters and must contain at least eight alphanumeric characters.

## `GET /healthz`

Returns `200 {"status":"ok"}`. It does not test Gemini or expose configuration.

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

Codes: `invalid_request` (400), framework validation (422), `rate_limited` (429), `invalid_model_output` (502), `model_unavailable` (503), and `internal_error` (500). The server times out Gemini after 15 seconds; Flutter times out the complete request after 20 seconds. The client does not retry silently.

## Demo-mode behavior

`DEMO_MODE=true` keeps this wire contract unchanged but replaces the Gemini service with deterministic extraction for known synthetic fixtures. Unsupported text returns `502 invalid_model_output`. Demo mode is never an automatic fallback: with `DEMO_MODE=false`, a missing `GEMINI_API_KEY` returns `503 model_unavailable`.
