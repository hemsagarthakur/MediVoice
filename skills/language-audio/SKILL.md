---
name: language-audio
description: Change MediVoice deterministic summaries, ML Kit translation, language-model download flow, or device text-to-speech.
---

# Language and Audio

Read `AGENTS.md`, `docs/SAFETY.md`, and `docs/DATA_SCHEMA.md`.

`SummaryBuilder` may combine confirmed fields but cannot add medical meaning. Translation receives only that verified English summary. English bypasses translation; Hindi and Telugu use downloaded ML Kit models. A translation failure preserves English and must not enable audio for partial translated text.

`SpeechService` checks the requested locale, speaks only a successful final result, supports play/stop/replay, and stops during navigation or a new scan. Missing voices leave readable text and clear installation guidance.

Use fakes for automated tests and validate target languages on the demo Android device.

