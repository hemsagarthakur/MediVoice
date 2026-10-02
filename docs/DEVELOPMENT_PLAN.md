# Development Plan

## Phase 0: foundation

Create agent guidance, documentation, contracts, Flutter/backend skeletons, synthetic data, linting, and base theme. Exit when both projects build or test and a new contributor can understand the system from repository docs.

## Phase 1: scanning pipeline

Implement camera/gallery preparation, on-device OCR, FastAPI live-provider extraction, validation, structured display, loading, and failure states. Exit when clear, missing-field, multi-medicine, strip, malformed, and offline samples behave safely.

## Phase 2: confirmation and language

Implement editing, uncertainty acknowledgement, deterministic summary, English/Hindi/Telugu translation, TTS, and the final result screen. Exit when the complete demo works without developer intervention.

## Phase 3: hardening

Complete automated tests, real-device checks, accessibility, lifecycle cleanup, Cloud Run runbook, failure polish, and measured sample evaluation. Optional icon/splash work starts only after all P0 checks pass.

At every phase: format, analyze/lint, run relevant tests, list changed files, record unresolved problems, and update docs when behavior changes.

## Checkpoint — 2026-09-29

Work stopped after the final safe local verification pass. Do not infer completion from implemented code alone; phase completion below includes the phase acceptance criteria.

### Phase status

- **Phase 0 — Complete.** The Git repository, documentation, agent guidance, synthetic fixtures, Flutter Android project, backend skeleton, canonical models, configuration, Android toolchain, tests, and debug APK build are present. The Android portion of `flutter doctor` passes.
- **Phase 1 — Implementation complete; acceptance pending external validation.** Camera/gallery, crop/rotate, image review, picker lost-data recovery, resolution warning, Latin OCR, extraction client, live-provider extraction, backend safety validation, and safe retry states are implemented. Cloud Run deployment, a live provider call, and real-device camera/gallery/OCR checks had not been performed at this checkpoint.
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
- Cloud Run deployment and live-provider smoke test: not run.

### Blockers and known environment gaps

- `gcloud` is not installed or configured, no Google Cloud project is selected, and no live-provider secret is available. `.env` is intentionally absent.
- No physical Android device or Android emulator is connected.
- The built APK intentionally points to `https://example.invalid`; it cannot perform live extraction until rebuilt with a deployed HTTPS `API_BASE_URL`.
- Flutter 3.47.0 is installed locally under `../.tooling/flutter` rather than on `PATH`; Flutter reports it as an unknown/user branch even though the framework version is 3.47.0.
- `flutter_tts` currently emits a non-failing warning that it still applies the Kotlin Gradle Plugin and may need a future package migration.
- iOS/macOS tooling is incomplete by design and is outside the Android-only MVP scope.

### Exact next task for a new Codex session

Resume with **Phase 1 external deployment and device acceptance**, without adding features:

1. Install/configure the Google Cloud CLI, select the intended project and region, enable Cloud Run/Build/Artifact Registry/Secret Manager APIs, and add the live-provider key to Secret Manager without writing it into the repository.
2. Build and deploy `backend/Dockerfile` to one unauthenticated, quota-limited Cloud Run instance with the configured provider model, `APP_ENV=production`, a 20-second service timeout, and the provider secret mounted only in the backend.
3. Verify `/healthz`, then run one synthetic OCR extraction and confirm logs contain only request ID, mode, character count, medicine count, timing, and error code.
4. Rebuild the APK with the deployed HTTPS URL: `flutter build apk --debug --dart-define=API_BASE_URL=https://<cloud-run-url>`.
5. Connect the demo Android device and execute the real-device matrix in `docs/TESTING.md`, beginning with camera/gallery, crop/rotation, lost-data recovery, OCR, and the deployed backend. Continue into Hindi/Telugu translation and TTS only after extraction passes.
6. Record exact device results and measured fixture accuracy here before declaring Phases 1–3 complete. Do not start icon, splash, authentication, persistence, or other optional scope.

## Checkpoint — 2026-10-01 (supersedes the previous next-task section)

The project is now complete for all implementation and automated validation that does not require a live-provider key, deployed backend URL, or physical Android device.

### Completed non-live scope

- **Phase 0 — Complete.** Foundation, contracts, documentation, Android project, backend, toolchain, fixtures, and agent guidance are present.
- **Phase 1 — Non-live implementation complete.** Camera/gallery, crop/rotation, lost-data recovery, image review, Latin OCR, HTTP extraction, deterministic fixture-bound mock extraction, safe live-mode failure without a key, validation, retry, and failure states are implemented. Debug Android builds can reach a local HTTP backend; release behavior remains HTTPS-oriented.
- **Phase 2 — Implementation and automated validation complete.** Multi-medicine review/editing, critical-field gating, explicit acknowledgement, suspicious-dose verification, deterministic English summaries, ML Kit English/Hindi/Telugu integration, translation fallback, TTS locale checks, Play/Stop/Replay, and lifecycle cleanup are implemented. Automated tests use fakes for platform services.
- **Phase 3 — Non-live implementation complete.** Demo disclosure, accessibility semantics, large touch targets, typed error panels, 15 synthetic fixtures, mock/live isolation tests, fail-closed unknown demo input, documentation, analyzer checks, and repeatable mock-mode APK builds are complete.

### Mock-mode behavior

- Backend `DEMO_MODE=true` selects `MockExtractionService` and does not initialize or call the live provider.
- Mock extraction recognizes only bundled synthetic patterns. Unsupported text returns `502 invalid_model_output` and never produces guessed medicine data.
- Flutter `--dart-define=DEMO_MODE=true` shows a clearly labelled **Try synthetic demo** action and persistent disclosures on review and result screens.
- Synthetic demo text flows through the normal HTTP client, backend schema, deterministic safety validator, mandatory confirmation, summary builder, on-device translation service, and device TTS service.
- With backend `DEMO_MODE=false`, the live provider is selected. A missing key returns safe `503 model_unavailable`; mock data is never used as a fallback.

### Latest automated verification

- Python compile check: passed.
- Backend pytest: 17 passed and 1 deferred live-provider test skipped by design at this checkpoint.
- Dart formatting: passed.
- Flutter analyzer: passed with no issues.
- Flutter unit/widget/workflow tests: 21 passed, including the demo-button-to-confirmed-result workflow.
- A real local Uvicorn process in `DEMO_MODE=true` returned `200` for `/healthz` and a schema-valid synthetic extraction without a key. Its log contained request ID, mode, character count, medicine count, and elapsed time, but not OCR text or medicine fields.
- Android mock-mode debug APK build passed with `DEMO_MODE=true` and `API_BASE_URL=http://10.0.2.2:8000`.
- The device-runner integration test remains source-complete and uses fakes, but cannot execute until an Android device or emulator is connected. Its host-runnable widget equivalent passed.

### Deferred manual/external work only

1. Supply and manually verify a real live-provider key with backend `DEMO_MODE=false`.
2. Deploy the unchanged live backend and configure a real HTTPS `API_BASE_URL`.
3. On a physical Android device, validate the real camera/OCR/backend path plus first-use Hindi/Telugu model downloads, installed TTS voices, playback lifecycle, TalkBack/text scaling, and repeated end-to-end runs.

Do not add features before those checks. To enable the live provider, set `DEMO_MODE=false` and the provider key in the backend environment, restart the backend, run Flutter with `--dart-define=DEMO_MODE=false`, and point `API_BASE_URL` at that backend. No Flutter code changes are expected.

## Checkpoint — 2026-10-02

The live LLM provider was replaced from Gemini to Groq without changing `/api/v1/extractions`, its JSON contract, Flutter networking, the demo extractor, or deterministic safety rules.

- Live mode uses `GroqExtractionService`, `GROQ_API_KEY`, configurable `GROQ_MODEL`, and default model `openai/gpt-oss-20b` through `https://api.groq.com/openai/v1`.
- The request uses Chat Completions strict JSON Schema mode with no tools, functions, AFC, or streaming. Returned message content is accepted only after `ExtractionPayload` validation.
- Strict schema generation now closes every object, requires every property, represents nullable strings as string/null unions, and retains the Pydantic length/cardinality constraints. This removes the prior schema drift that allowed a provider `200` which local Pydantic validation could reject.
- Development Groq HTTP 400 diagnostics retain only sanitized provider metadata. Invalid-output diagnostics contain only validation path/type; neither log path records OCR, generated prescription content, or keys.
- Fully empty array-padding objects from the constrained model are removed without adding or altering medicine data; an entirely empty extraction still fails closed.
- Missing, blank, malformed, or schema-invalid output fails closed as `502 invalid_model_output`.
- `DEMO_MODE=true` still selects only `MockExtractionService`; Groq is never initialized or called.
- A missing live key still returns `503 model_unavailable`; provider rate limiting maps to the existing retryable `429` envelope.
- The real-looking key found in `.env.example` was removed. That key must be rotated because repository example files are not secret storage.
- Final verification: Python compilation passed; backend pytest passed with 30 tests and 1 intentionally skipped manual-live placeholder. The previously completed Flutter formatting, analyzer, and 21 tests remain unaffected because this fix changed no Flutter files.
- A restarted local FastAPI process returned `200` from `/healthz`. A real request using `sample_data/clear_single.txt` passed through the live Groq route and returned `200` with one grounded Paracetamol item, required null keys, and the unchanged response schema. Logs did not include the key or OCR text.

## Checkpoint — 2026-10-02 comprehension-first result flow

- The post-extraction experience now uses one simple review headed **We found X medicines**. Confident fields have one **Looks correct** action and no per-field acknowledgement; **Something is wrong** reveals correction fields on demand.
- Extractor-marked uncertainty remains highlighted and gated. A missing medicine name still blocks progress, and the deterministic suspicious-dose acknowledgement remains unchanged.
- `SummaryBuilder` now produces short plain-language English explanations, explicitly states missing facts, naturalizes common frequency phrases, and never supplies purpose, side effects, or unsupported treatment information.
- Hindi and Telugu use on-device prose translation after confirmation. Medicine names, strengths, and numeric facts are protected from translation and must restore exactly or translation fails closed to the checked English explanation.
- The result screen prioritizes medicine names, the easy explanation, language choice, a large **Listen** action, Stop/Replay, and **Scan another prescription**. TTS speaks the selected localized explanation at rate `0.42` using `en-IN`, `hi-IN`, or `te-IN`.
- Verification passed: formatting, `flutter analyze`, 28 Flutter unit/widget tests, the Android integration test, and debug APK assembly/install. No OCR, extraction endpoint, or wire-contract code changed for this redesign.
- Remaining manual validation: judge Hindi/Telugu wording on real prescriptions, verify first-use model downloads and installed voices on the target physical device, and complete TalkBack/text-scaling review. On-device translation quality can vary; the checked English explanation remains available and protected-fact corruption fails closed.

## Trusted medicine-reference checkpoint (2026-10-02)

- **Implementation complete.** A separate post-confirmation reference service uses RxNorm for identity, DailyMed as the preferred label source, and openFDA drug labels as fallback. The Groq extraction contract, OCR, dosage handling, and deterministic safety gates are unchanged.
- Only medicine name and uncertainty are sent from Flutter. Uncertain combination names fail closed without an external lookup. A bounded in-memory backend cache stores public reference results only.
- Result cards clearly separate **Your doctor's instructions** from collapsible **About this medicine** facts. The combined verified explanation includes supported reference facts for translation and TTS, while excluding source URLs, RxCUI values, and API metadata.
- Reference lookup and parsing failures are non-blocking and render a clear unavailable state.
- Automated verification: 50 backend tests passed with 1 intentionally deferred live-Groq test skipped; Python compilation passed; Flutter analyzer passed; all 38 Flutter unit/widget tests passed; and the mock-mode debug APK built successfully. Live public lookups through the FastAPI endpoint succeeded for Paracetamol and Azithromycin; `Levosalbutamdl + Ambroxdl` was correctly unavailable.
- Remaining manual work: physical-device review of expanded cards, Hindi/Telugu natural wording with reference facts, installed voice behavior, and product/clinical review of deterministic label simplification. Live Groq deployment/device validation remains separately deferred as documented above.

## Focused result-language checkpoint (2026-10-02)

- Language changes now remain on the result screen instead of returning the whole workflow to the processing screen. The controlled selector, explicit language-pack progress state, visible failure message, and debug-only readiness/success/failure logs make Hindi selection deterministic and diagnosable without logging medicine text.
- Confirmed summaries now use compact medicine headings and one short instruction paragraph. Trusted reference display/TTS is capped at one use, three side effects, and one caution; long regulatory text, label section numbers, and study wording are omitted.
- Physical Android verification passed for Hindi and Telugu ML Kit translation with protected facts. Hindi TTS selected the installed `hi-IN` voice. Automated Flutter tests cover visible Hindi replacement and repeated English/Hindi/Telugu switching.
- Follow-up device diagnosis found that ML Kit could alter the old alphabetic protection markers in a longer multi-medicine Hindi explanation, causing the safety restoration check to reject an otherwise completed translation. Protection now uses one-pass indexed markers with case/spacing-tolerant restoration. The exact five-medicine Hindi regression and `hi-IN` speech check pass on the physical Android device; all 42 Flutter tests and the debug APK build pass.

## Checkpoint — 2026-10-02 repeated-scan Groq hardening

- The provider-only schema now accepts `medicines: []`; the unchanged public success payload still requires one to ten medicines. After provider validation, zero substantive items return deterministic `no_medicine_detected` without inventing data.
- Missing top-level or medicine-level `warnings` normalize to empty lists before the final `ExtractionPayload` is created.
- Strict JSON Schema remains the first request. Only Groq HTTP 400 codes `json_validate_failed` and `json_schema_validation_failed` trigger one JSON-object fallback; both responses pass through Pydantic and deterministic safety validation. There are never more than two provider calls for this condition.
- OpenAI SDK automatic retries are disabled. A 429 causes no fallback or immediate retry and propagates a valid `Retry-After` header in the existing error response.
- Extraction uses `reasoning_effort=low` and a 4,096-token completion limit, retaining capacity for the ten-medicine maximum while reducing repeated-scan cost and latency.
- Backend automated verification: 41 tests passed and one intentionally deferred live test was skipped. Two sequential local live requests using different OCR fixtures both returned HTTP 200: `clear_single.txt` produced one Paracetamol item after the strict request reproduced `json_validate_failed` for missing `warnings` and the single fallback succeeded; `multiple_medicines.txt` succeeded in strict mode with Amoxicillin and Paracetamol. No 429 occurred and no automatic retry was made.

## Checkpoint — 2026-10-02 confidence review and debug OCR routing

- OCR now proceeds directly to extraction and the medicine review screen. The former workflow-blocking Developer OCR check state was removed.
- Raw OCR remains available only from a `kDebugMode`-gated developer action on the completed review screen. Disabling that capability removes the action and raw text from the reachable flow.
- Review now shows deterministic High, Medium, or Low confidence with no percentage. Critical missing/uncertain data, warnings, conflicts, and suspicious dose counts are Low; optional gaps or non-critical uncertainty are Medium; complete certain core data is High.
- All uncertain fields and missing critical fields remain highlighted and gated. **Review unclear details** exposes only the affected editors; confident fields require no extra confirmation.
- Flutter formatting passed, analyzer reported no issues, all 31 unit/widget tests passed, and the debug APK built successfully. The Android integration test could not start because no supported Android device or emulator was connected; its fake-service widget equivalent passed.
