---
name: testing
description: Add or run MediVoice tests and evaluate the guarded scan-to-speech workflow with synthetic data.
---

# MediVoice Testing

Read `docs/TESTING.md` and `docs/SAFETY.md`. Use only synthetic or anonymized fixtures.

Prioritize observable safety invariants over implementation details: missing values stay null, strips do not gain dosage, uncertainty blocks or requires acknowledgement, invalid AI output fails closed, and translation/audio use confirmed text only.

Use hand-written fakes at service boundaries. Run Dart formatting, Flutter analyzer/tests, pytest, and relevant real-device checks. Report commands, outcomes, skipped device checks, and unresolved risks; do not report a plugin feature as verified from a fake-only test.

