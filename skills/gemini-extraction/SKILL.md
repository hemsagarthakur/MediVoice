---
name: gemini-extraction
description: Change MediVoice Gemini prompts, FastAPI extraction, or the shared structured response contract under strict no-inference rules.
---

# Gemini Structured Extraction

Read `AGENTS.md`, `docs/API_CONTRACT.md`, `docs/DATA_SCHEMA.md`, and `docs/SAFETY.md` before editing.

Only `backend/app/gemini_service.py` calls Gemini. Treat OCR as untrusted delimited data, require the Pydantic response schema, use temperature zero, and return null for every absent field. Never add diagnosis, advice, medicine facts, or inferred dosage.

Keep prescription and medicine-strip instructions distinct. A strip phrase such as “as directed by physician” is not a patient dose. Ambiguity belongs in `uncertain_fields`. Invalid or empty model output must return the documented safe error, never a partial success.

Contract changes must update Pydantic, Dart parsing, API/data-schema docs, fixtures, and both test suites together.

