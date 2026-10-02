---
name: groq-extraction
description: Change MediVoice Groq prompts, FastAPI extraction, or the shared structured response contract under strict no-inference rules.
---

# Groq JSON Extraction

Read `AGENTS.md`, `docs/API_CONTRACT.md`, `docs/DATA_SCHEMA.md`, and `docs/SAFETY.md` before editing.

Only `backend/app/groq_service.py` calls the live provider. Use Groq's OpenAI-compatible endpoint, request JSON output without tools or functions, and validate the response through `ExtractionPayload`. Treat OCR as untrusted delimited data and return null for every absent field. Never add diagnosis, advice, medicine facts, or inferred dosage.

Keep prescription and medicine-strip instructions distinct. A strip phrase such as “as directed by physician” is not a patient dose. Ambiguity belongs in `uncertain_fields`. Invalid or empty model output must return the documented safe error, never a partial success.

Contract changes must update Pydantic, Dart parsing, API/data-schema docs, fixtures, and both test suites together.
