---
name: safety-validation
description: Modify MediVoice medical-safety validation, confirmation gates, null handling, or medicine-strip safeguards.
---

# Safety Validation

Read `AGENTS.md` and `docs/SAFETY.md`. Safety validation is deterministic and cannot be delegated to model confidence.

- A scan needs at least one medicine; each medicine needs a user-confirmed name.
- Null or uncertain strength, dose, frequency, and timing must remain visible and require acknowledgement unless corrected.
- Preserve the original extraction during the active session.
- Medicine-strip results always include the dosage-availability warning.
- Translation and speech remain blocked until all medicine cards pass confirmation.

Add tests for every changed rule, including missing, ambiguous, edited, acknowledged, strip, and multi-medicine cases. Never weaken a rule solely to satisfy an existing test.

