# MediVoice Project Specification

## Goal

Help patients and caregivers understand instructions already present on prescriptions and medicine packaging through scanning, structured review, translation, and speech.

## Users and use cases

Primary users are elderly people, low-literacy users, rural patients, people who do not understand English instructions, and caregivers. A user may photograph or upload either a prescription or medicine strip, review all extracted medicines on one simple screen, correct or acknowledge only information that needs attention, choose English, Hindi, or Telugu, and listen to a plain-language explanation.

## Functional requirements

1. Offer prescription scan, medicine-strip scan, and gallery upload.
2. Allow crop, rotation, preview, retake, and confirmation.
3. Extract Latin-script text on device and retain the raw OCR text only for the active session.
4. Convert OCR text into the schema in `DATA_SCHEMA.md`, including every detected medicine.
5. Return null for absent information and flag ambiguous fields.
6. Require one medicine-level review before explanation, localization, or speech; confident fields do not require individual confirmation.
7. Highlight uncertain fields and require their acknowledgement or correction while preserving the original extraction during the session. Expose affected editors through **Review unclear details** without forcing confident fields through another confirmation step.
8. Show deterministic High, Medium, or Low scan confidence from validation, missing-data, uncertainty, warning, and suspicious-dose signals. Do not fabricate a percentage.
9. Build a deterministic, short, plain-language English explanation from confirmed fields without adding medical facts.
10. Localize the confirmed explanation to natural Hindi or Telugu prose on device while preserving medicine names, strengths, numbers, and instructions.
11. Speak the localized explanation using an installed device voice.
12. Fail safely with retry or rescan guidance.

## Nonfunctional requirements

- Android-first, responsive, high-contrast, large-target UI.
- No permanent scan storage or patient identity.
- No sensitive values in logs.
- One stateless backend with a 15-second Groq timeout.
- Typed null-safe Flutter code and validated backend models.
- Services must be replaceable by fakes in tests.

## MVP boundaries

The MVP excludes diagnosis, prescribing, treatment planning, medicine-reference facts, interaction checking, medical-correctness validation, history, accounts, notifications, analytics, and full UI localization. Input OCR is Latin-script only.

## Success criteria

- A user can complete camera/gallery to spoken result without developer help.
- Missing values are never invented.
- Every uncertain field requires correction or acknowledgement; confident fields can be accepted together.
- Medicine-strip scans do not create patient-specific dosage.
- All documented failure categories produce safe, recoverable UI.
- The primary demo succeeds five consecutive times on the target Android device.

Future scope must preserve the safety boundaries in `SAFETY.md`.
