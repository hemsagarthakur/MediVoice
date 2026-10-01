# Medical Safety Boundaries

## What MediVoice does

MediVoice explains text already visible on a prescription or medicine label. It extracts fields, asks the user to verify them, preserves missing information, translates the verified summary, and reads it aloud.

## What it never does

MediVoice does not diagnose, prescribe, recommend treatment, validate a prescription's medical correctness, infer missing instructions, change dosage, detect all interactions, or generate medicine purpose, side effects, or warnings from model memory.

## Extraction and uncertainty

- Gemini receives OCR text as untrusted data and must return null for absent fields.
- Schema validation is necessary but does not prove semantic correctness.
- A missing medicine name blocks confirmation.
- Null or uncertain strength, dose, frequency, or timing is highlighted and requires explicit acknowledgement.
- A per-dose count of five or more tablets, capsules, or puffs triggers an additional deterministic verification warning and acknowledgement; it is not presented as a medical judgment.
- The original OCR and original extraction remain available only during the active review session.
- Invalid, empty, or unusable extraction stops the flow with retry/rescan guidance.

## Medicine-strip policy

Packaging often lacks patient-specific directions. The extractor must not treat product strength or phrases such as “dosage as directed by physician” as patient dosage. The confirmation and result screens always remind the user to check the prescription or pharmacist when dosage is unavailable.

## Translation and speech

Only a confirmed deterministic English summary may be translated. Speech uses only the selected successful translation. Translation or TTS failure never modifies confirmed fields and never causes a generated fallback instruction.

## Privacy and external processing

No patient identity is required. Images stay on the device. In live mode, OCR text is sent to the backend and Gemini. In explicit demo mode, it is sent only to the mock backend and must match synthetic fixtures. MediVoice does not persist or log it in either mode. Tests use synthetic or anonymized data.

Demo mode never activates as a fallback for a failed live request, never invents data for unknown text, and cannot bypass review, acknowledgement, strip safeguards, deterministic summary generation, translation gating, or speech gating.

## Emergencies and trusted data

The app provides no emergency triage. Users must contact qualified clinicians or emergency services for urgent concerns. Future medicine-reference features require a named, versioned, trusted source and separate clinical review.

## Safety tests

Tests must prove that missing dose/duration remain null, strip scans do not create dosage, suspicious fields require acknowledgement, malformed AI output fails closed, translation uses confirmed text, and unsafe prompt content cannot alter the schema or instructions.
