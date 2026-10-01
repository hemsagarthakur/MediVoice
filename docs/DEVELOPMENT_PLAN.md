# Development Plan

## Phase 0: foundation

Create agent guidance, documentation, contracts, Flutter/backend skeletons, synthetic data, linting, and base theme. Exit when both projects build or test and a new contributor can understand the system from repository docs.

## Phase 1: scanning pipeline

Implement camera/gallery preparation, on-device OCR, FastAPI Gemini extraction, validation, structured display, loading, and failure states. Exit when clear, missing-field, multi-medicine, strip, malformed, and offline samples behave safely.

## Phase 2: confirmation and language

Implement editing, uncertainty acknowledgement, deterministic summary, English/Hindi/Telugu translation, TTS, and the final result screen. Exit when the complete demo works without developer intervention.

## Phase 3: hardening

Complete automated tests, real-device checks, accessibility, lifecycle cleanup, Cloud Run runbook, failure polish, and measured sample evaluation. Optional icon/splash work starts only after all P0 checks pass.

At every phase: format, analyze/lint, run relevant tests, list changed files, record unresolved problems, and update docs when behavior changes.

## Checkpoint — 2026-09-29

Work stopped after the final safe local verification pass. Do not infer completion from implemented code alone; phase completion below includes the phase acceptance criteria.

### Phase status

- **Phase 0 — Complete.** The Git repository, documentation, agent guidance, synthetic fixtures, Flutter Android project, backend skeleton, canonical models, configuration, Android toolchain, tests, and debug APK build are present. The Android portion of `flutter doctor` passes.
- **Phase 1 — Implementation complete; acceptance pending external validation.** Camera/gallery, crop/rotate, image review, picker lost-data recovery, resolution warning, Latin OCR, extraction client, Gemini structured extraction, backend safety validation, and safe retry states are implemented. Cloud Run deployment, a live Gemini call, and real-device camera/gallery/OCR checks have not been performed.
- **Phase 2 — Implementation complete; acceptance pending real-device validation.** Multi-medicine editing and confirmation, missing/uncertain-field acknowledgement, deterministic summaries, English/Hindi/Telugu translation, translation fallback, and TTS controls are implemented and fake-service tests pass. Hindi/Telugu model downloads, installed voice behavior, and audio lifecycle still require a physical Android device.
- **Phase 3 — In progress.** Automated hardening, typed failures, lifecycle cleanup, accessibility semantics, 15 synthetic fixtures, documentation, and repeatable debug builds are present. The required five real-device end-to-end runs, field-accuracy measurement, TalkBack/manual accessibility review, venue-network exercise, deployed-service verification, and final evaluation report remain outstanding.

### Working now

- Flutter app compiles into `app/build/app/outputs/flutter-apk/app-debug.apk`.
- The fake-service end-to-end workflow reaches a confirmed result.
- FastAPI health and extraction routes, strict request/response models, size limits, status mapping, timeouts, strip-mode dosage removal, and safe error envelopes are covered by tests.
- Images remain local; only OCR text is serialized to the backend. Production UI does not expose provider errors or stack traces, and backend logs omit OCR/prescription content.
- The repository is initialized on branch `main`; no initial commit has been created.

### Verification results

- `dart format --set-exit-if-changed lib test integration_test`: passed.
- `flutter analyze`: passed with no issues.
- `flutter test`: 17 tests passed.
- `python -m pytest backend`: 11 tests passed. One non-failing FastAPI/Starlette `TestClient` deprecation warning about `httpx` remains.
- Six repository skills pass the skill-creator `quick_validate.py` check.
- `flutter build apk --debug --dart-define=API_BASE_URL=https://example.invalid`: passed.
- Android toolchain check: passed with Android SDK 36; `targetSdk` remains 35. `compileSdk` is 36 because current Flutter plugins require it.
- Android integration/real-device tests: not run because no Android device or emulator is connected.
- Docker image build: not run because Docker is not installed.
- Cloud Run deployment and live Gemini smoke test: not run.

### Blockers and known environment gaps

- `gcloud` is not installed or configured, no Google Cloud project is selected, and no Gemini secret is available. `.env` is intentionally absent.
- No physical Android device or Android emulator is connected.
- The built APK intentionally points to `https://example.invalid`; it cannot perform live extraction until rebuilt with a deployed HTTPS `API_BASE_URL`.
- Flutter 3.47.0 is installed locally under `../.tooling/flutter` rather than on `PATH`; Flutter reports it as an unknown/user branch even though the framework version is 3.47.0.
- `flutter_tts` currently emits a non-failing warning that it still applies the Kotlin Gradle Plugin and may need a future package migration.
- iOS/macOS tooling is incomplete by design and is outside the Android-only MVP scope.

### Exact next task for a new Codex session

Resume with **Phase 1 external deployment and device acceptance**, without adding features:

1. Install/configure the Google Cloud CLI, select the intended project and region, enable Cloud Run/Build/Artifact Registry/Secret Manager APIs, and add the Gemini key to Secret Manager without writing it into the repository.
2. Build and deploy `backend/Dockerfile` to one unauthenticated, quota-limited Cloud Run instance with `GEMINI_MODEL=gemini-3.8-flash`, `APP_ENV=production`, a 20-second service timeout, and the secret mounted as `GEMINI_API_KEY`.
3. Verify `/healthz`, then run one synthetic OCR extraction and confirm logs contain only request ID, mode, character count, medicine count, timing, and error code.
4. Rebuild the APK with the deployed HTTPS URL: `flutter build apk --debug --dart-define=API_BASE_URL=https://<cloud-run-url>`.
5. Connect the demo Android device and execute the real-device matrix in `docs/TESTING.md`, beginning with camera/gallery, crop/rotation, lost-data recovery, OCR, and the deployed backend. Continue into Hindi/Telugu translation and TTS only after extraction passes.
6. Record exact device results and measured fixture accuracy here before declaring Phases 1–3 complete. Do not start icon, splash, authentication, persistence, or other optional scope.

## Checkpoint — 2026-10-01 (supersedes the previous next-task section)

The project is now complete for all implementation and automated validation that does not require a live Gemini key, deployed backend URL, or physical Android device.

### Completed non-live scope

- **Phase 0 — Complete.** Foundation, contracts, documentation, Android project, backend, toolchain, fixtures, and agent guidance are present.
- **Phase 1 — Non-live implementation complete.** Camera/gallery, crop/rotation, lost-data recovery, image review, Latin OCR, HTTP extraction, deterministic fixture-bound mock extraction, safe live-mode failure without a key, validation, retry, and failure states are implemented. Debug Android builds can reach a local HTTP backend; release behavior remains HTTPS-oriented.
- **Phase 2 — Implementation and automated validation complete.** Multi-medicine review/editing, critical-field gating, explicit acknowledgement, suspicious-dose verification, deterministic English summaries, ML Kit English/Hindi/Telugu integration, translation fallback, TTS locale checks, Play/Stop/Replay, and lifecycle cleanup are implemented. Automated tests use fakes for platform services.
- **Phase 3 — Non-live implementation complete.** Demo disclosure, accessibility semantics, large touch targets, typed error panels, 15 synthetic fixtures, mock/live isolation tests, fail-closed unknown demo input, documentation, analyzer checks, and repeatable mock-mode APK builds are complete.

### Mock-mode behavior

- Backend `DEMO_MODE=true` selects `MockExtractionService` and does not initialize or call Gemini.
- Mock extraction recognizes only bundled synthetic patterns. Unsupported text returns `502 invalid_model_output` and never produces guessed medicine data.
- Flutter `--dart-define=DEMO_MODE=true` shows a clearly labelled **Try synthetic demo** action and persistent disclosures on review and result screens.
- Synthetic demo text flows through the normal HTTP client, backend schema, deterministic safety validator, mandatory confirmation, summary builder, on-device translation service, and device TTS service.
- With backend `DEMO_MODE=false`, the original Gemini service is unchanged. A missing key returns safe `503 model_unavailable`; mock data is never used as a fallback.

### Latest automated verification

- Python compile check: passed.
- Backend pytest: 17 passed and 1 deferred live-Gemini test skipped by design. A non-failing Starlette `TestClient`/`httpx` deprecation warning remains.
- Dart formatting: passed.
- Flutter analyzer: passed with no issues.
- Flutter unit/widget/workflow tests: 21 passed, including the demo-button-to-confirmed-result workflow.
- A real local Uvicorn process in `DEMO_MODE=true` returned `200` for `/healthz` and a schema-valid synthetic extraction without a key. Its log contained request ID, mode, character count, medicine count, and elapsed time, but not OCR text or medicine fields.
- Android mock-mode debug APK build passed with `DEMO_MODE=true` and `API_BASE_URL=http://10.0.2.2:8000`.
- The device-runner integration test remains source-complete and uses fakes, but cannot execute until an Android device or emulator is connected. Its host-runnable widget equivalent passed.

### Deferred manual/external work only

1. Supply and manually verify a real `GEMINI_API_KEY` with backend `DEMO_MODE=false`.
2. Deploy the unchanged live backend and configure a real HTTPS `API_BASE_URL`.
3. On a physical Android device, validate the real camera/OCR/backend path plus first-use Hindi/Telugu model downloads, installed TTS voices, playback lifecycle, TalkBack/text scaling, and repeated end-to-end runs.

Do not add features before those checks. To enable Gemini later, set `DEMO_MODE=false` and `GEMINI_API_KEY` in the backend environment, restart the backend, run Flutter with `--dart-define=DEMO_MODE=false`, and point `API_BASE_URL` at that backend. No code changes are expected.
