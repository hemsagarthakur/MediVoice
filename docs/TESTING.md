# Testing Strategy

## Automated layers

- Dart model tests cover null normalization and API parsing.
- Service tests use fakes for HTTP, OCR, translation, and speech.
- Medicine-reference tests cover exact and typo normalization, ambiguous/no matches, unavailable sources, supported uses/side effects/caution extraction, privacy-minimal requests, and in-memory cache hits.
- Safety and explanation tests prove that missing data stays missing, supported facts become natural short sentences, and no medical instruction is added.
- Widget tests prove that confident results use one quick review, High/Medium/Low labels follow deterministic safety signals, uncertain fields remain highlighted and gated, and only unclear editors appear on request.
- Translation protection tests preserve medicine names, strengths, and numbers; controller tests prove speech receives the selected localized explanation.
- Language-switching tests cover English → Hindi → Telugu → English without leaving the result screen. A physical-device integration test downloads the Hindi/Telugu ML Kit models, verifies their native scripts and protected facts, and checks that the installed Hindi voice accepts `hi-IN`.
- A Flutter integration test runs the full workflow with fake platform services.
- Pytest covers request validation, prompt configuration, mocked Groq JSON output, empty detections, warning normalization, the single controlled schema fallback, no-retry 429 handling, provider failure mapping, response validation, strip safeguards, and error envelopes.
- Pytest covers explicit demo/live routing, known synthetic extraction, unknown-text fail-closed behavior, and confirms strip safeguards still run after mock extraction.

## Required scenarios

1. Clear single medicine.
2. Poor-resolution or unreadable image.
3. Missing dosage.
4. Missing duration.
5. Incorrect or uncertain medicine name.
6. Medicine strip only.
7. Multiple medicines.
8. Malformed Groq response.
9. No network or backend timeout.
10. Translation failure.
11. Unsupported language.
12. TTS unavailable.
13. Empty OCR.
14. Suspicious or uncertain dose.
15. Fragmented multi-column OCR whose medicine, dose/modifier, and duration rows arrive in separate ordered groups.

Use at least 15 synthetic or anonymized fixtures. Clear typed samples target 90% exact match on medicine name, strength, dose, frequency, and duration. Missing-dose and strip samples require zero invented dosage values. All malformed/empty/provider failures must fail safely.

`sample_data/fragmented_columns_device_ocr.txt` preserves the explicitly supplied 44-line device OCR exactly. Prompt tests verify line numbering and mechanical candidate grouping; the mocked provider regression verifies five-medicine schema preservation. Live verification remains manual because Groq is excluded from the default suite.

## Real-device checks

On the demo Android device, verify camera/gallery permissions, lost image recovery, crop/rotation, ML Kit OCR, first-use Hindi/Telugu model downloads, installed voices, playback stop on navigation, text scaling, TalkBack labels, 48dp touch targets, five consecutive full demo runs, and behavior on venue-quality network.

On 2026-10-02, `integration_test/language_audio_device_test.dart` passed on the connected Android 14 device: first-use Hindi and Telugu models downloaded, translations contained the expected native scripts while preserving medicine name/strength/dose/duration, and Hindi TTS selected `hi-IN` successfully.

OCR proceeds directly into extraction and medicine review. Debug builds expose a developer icon on the review screen that opens the exact in-memory OCR text for inspection or copying. The action is absent when debug viewing is disabled and unreachable in release builds; it does not persist or log OCR text.

## Commands

```bash
cd app && dart format --set-exit-if-changed .
cd app && flutter analyze
cd app && flutter test
cd app && flutter test integration_test/full_workflow_test.dart
python -m pytest backend
```

The default suites require no Groq key. The live-provider pytest placeholder is intentionally skipped and documents the manual acceptance test.

## Mock-mode acceptance

1. Copy `.env.example` to `.env`; leave `GROQ_API_KEY` empty and keep `DEMO_MODE=true`.
2. Start FastAPI and run Flutter with `--dart-define=DEMO_MODE=true` and the local backend URL.
3. Tap **Try synthetic demo** and verify review appears before translation or audio.
4. Verify the demo disclosure remains visible on review and result screens.
5. Confirm that unknown OCR text fails safely rather than producing a plausible medicine.
6. Run a medicine-strip fixture and verify dose, frequency, timing, duration, and food instructions remain null.

## Manual live acceptance

Only when a real key is intentionally provided: set backend `DEMO_MODE=false`, restart it, verify one synthetic live extraction, then complete the physical-device camera/OCR/API matrix. Live calls remain excluded from the default automated suite. On 2026-10-02, the local FastAPI health check and one synthetic Groq extraction passed; deployed-backend and physical-device verification remain outstanding.

Public reference verification does not require a Groq key. Start the backend, confirm `/healthz`, then call `/api/v1/medicine-references` with `Paracetamol`, `Azithromycin`, and one uncertain or misspelled name. Verify that only medicine identity is sent, trusted-label facts stay short, ambiguous input is unavailable, and a source outage does not prevent the result screen or audio from using confirmed prescription instructions.
