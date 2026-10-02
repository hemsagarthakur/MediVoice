# MediVoice Agent Instructions

## Project objective

MediVoice is an Android Flutter application that reads prescription or medicine-label text, asks the user to verify it, and provides a simplified translated spoken summary. It explains only information visible in the source and never diagnoses or prescribes.

## Required reading

Before changing code, read this file and the relevant documents in `docs/`. Read `docs/SAFETY.md` for every extraction, validation, confirmation, summary, translation, or speech change. Read `docs/API_CONTRACT.md` and `docs/DATA_SCHEMA.md` before changing a shared model.

## Architecture rules

- Flutter is the only client. Keep UI in widgets, workflow state in `ScanController`, and external capabilities behind services.
- Never call Groq from widgets or from the Flutter client. The FastAPI backend is the only live LLM caller.
- Keep demo extraction explicitly enabled, deterministic, and limited to synthetic fixtures. Never silently fall back from failed live extraction to demo data.
- OCR, extraction API, validation, summary, translation, and speech logic belong in their named services.
- Maintain one canonical model per concept inside each language. Keep Dart and Pydantic wire contracts aligned.
- Keep scans in memory. Do not add persistence, accounts, Firebase, analytics, or additional cloud services without an approved architecture change.
- Prefer the smallest working implementation. Do not introduce alternate state-management, routing, networking, or serialization frameworks.

## Safety rules

- Never invent, infer, recommend, or change a dose or medicine instruction.
- Missing information remains null and is shown as "Not detected."
- A missing medicine name blocks confirmation. Other missing or uncertain critical fields require explicit acknowledgement.
- Medicine-strip recognition must not create patient-specific dosage instructions.
- Translation and speech operate only on user-confirmed summaries.
- Do not remove validation, confirmation, warnings, or safe failure behavior to make a test pass.
- Do not add medicine purpose, side effects, interactions, diagnosis, or treatment advice without trusted reference data and an approved scope change.

## Coding and privacy rules

- Use Dart null safety, strong types, focused widgets, and injected service interfaces.
- Centralize user-facing errors and never show raw exceptions in release UI.
- Never commit or log secrets, images, OCR text, prescription fields, or translated summaries.
- The backend accepts OCR text only and must not persist request content.
- Avoid new dependencies unless they solve a documented P0 problem.
- Preserve unrelated working code and update documentation when contracts or architecture change.

## Required checks

Run the relevant subset and report results:

```bash
cd app && dart format --set-exit-if-changed .
cd app && flutter analyze
cd app && flutter test
python -m pytest backend
```

For mobile-plugin changes, also perform a real Android-device smoke test. Report changed files, checks performed, and unresolved limitations.

## Forbidden behavior

Do not hardcode API keys, suppress exceptions without explanation, return fake success data, silently change the wire schema, duplicate business logic in widgets, replace the architecture without justification, or delete functioning features unnecessarily.
