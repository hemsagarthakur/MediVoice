# Testing Strategy

## Automated layers

- Dart model tests cover null normalization and API parsing.
- Service tests use fakes for HTTP, OCR, translation, and speech.
- Safety and summary tests prove that missing data stays missing and confirmation gates work.
- Widget tests cover accessible labels, uncertain-field highlights, edit/save, acknowledgement, and retry UI.
- A Flutter integration test runs the full workflow with fake platform services.
- Pytest covers request validation, prompt configuration, Gemini failure mapping, response validation, strip safeguards, and error envelopes.
- Pytest covers explicit demo/live routing, known synthetic extraction, unknown-text fail-closed behavior, and confirms strip safeguards still run after mock extraction.

## Required scenarios

1. Clear single medicine.
2. Poor-resolution or unreadable image.
3. Missing dosage.
4. Missing duration.
5. Incorrect or uncertain medicine name.
6. Medicine strip only.
7. Multiple medicines.
8. Malformed Gemini response.
9. No network or backend timeout.
10. Translation failure.
11. Unsupported language.
12. TTS unavailable.
13. Empty OCR.
14. Suspicious or uncertain dose.

Use at least 15 synthetic or anonymized fixtures. Clear typed samples target 90% exact match on medicine name, strength, dose, frequency, and duration. Missing-dose and strip samples require zero invented dosage values. All malformed/empty/provider failures must fail safely.

## Real-device checks

On the demo Android device, verify camera/gallery permissions, lost image recovery, crop/rotation, ML Kit OCR, first-use Hindi/Telugu model downloads, installed voices, playback stop on navigation, text scaling, TalkBack labels, 48dp touch targets, five consecutive full demo runs, and behavior on venue-quality network.

## Commands

```bash
cd app && dart format --set-exit-if-changed .
cd app && flutter analyze
cd app && flutter test
cd app && flutter test integration_test
python -m pytest backend
```

The default suites require no Gemini key. The live-provider pytest placeholder is intentionally skipped and documents the deferred manual acceptance test.

## Mock-mode acceptance

1. Copy `.env.example` to `.env`; leave `GEMINI_API_KEY` empty and keep `DEMO_MODE=true`.
2. Start FastAPI and run Flutter with `--dart-define=DEMO_MODE=true` and the local backend URL.
3. Tap **Try synthetic demo** and verify review appears before translation or audio.
4. Verify the demo disclosure remains visible on review and result screens.
5. Confirm that unknown OCR text fails safely rather than producing a plausible medicine.
6. Run a medicine-strip fixture and verify dose, frequency, timing, duration, and food instructions remain null.

## Deferred live acceptance

Only after a real key and backend URL are intentionally provided: set backend `DEMO_MODE=false`, restart it, run Flutter with `DEMO_MODE=false`, verify one synthetic live extraction, then complete the physical-device camera/OCR/API matrix. This work is deliberately excluded from the default automated suite.
