# MediVoice

A prescription and medicine-label accessibility app that converts medicine instructions into simple, spoken explanations in the user’s preferred language.

## 💡 Project overview

MediVoice helps elderly users, low-literacy users, rural users, and caregivers understand medicine instructions that may be handwritten, small, or available only in English. A user scans or uploads a prescription or medicine label, crops the image, and runs on-device OCR. The app then extracts structured medicine details, shows a confidence-based review, creates a plain-language explanation, optionally adds trusted medicine-reference information, translates the result into English, Hindi, or Telugu, and reads it aloud.

MediVoice explains existing information. It does not diagnose, prescribe, or change dosage. Missing or uncertain critical information remains visible and requires review.

## ✨ Key features

- Camera and gallery input with crop and rotation
- On-device Latin-script OCR with Google ML Kit
- Groq-powered structured extraction using `openai/gpt-oss-20b`
- Multi-medicine extraction and fragmented prescription-column handling
- Deterministic High, Medium, or Low confidence labels
- Selective review of unclear fields without re-confirming confident fields
- Short, deterministic plain-language medicine instructions
- Trusted general reference information: commonly used for, up to three common side effects, and one important caution
- RxNorm medicine normalization, DailyMed lookup, and openFDA fallback
- English, Hindi, and Telugu explanations with protected medicine facts
- Android text-to-speech with Listen, Stop, and Replay
- Safe fallback when medicine-reference data is unavailable
- Explicit mock mode for key-free demonstrations with synthetic fixtures
- No accounts, analytics, scan history, or persistent prescription storage

## 🛠️ Technologies used

### Mobile

- Flutter and Dart
- Provider with `ChangeNotifier`
- Google ML Kit Text Recognition and Translation
- `image_picker` and `image_cropper`
- `flutter_tts`
- `http`

### Backend

- Python 3.12
- FastAPI, Uvicorn, Pydantic, and Pydantic Settings
- Groq through its OpenAI-compatible API
- `openai/gpt-oss-20b` by default

### Medicine reference

- RxNorm API
- DailyMed Web Services
- openFDA Drug Label API

### Testing

- Flutter unit, widget, and integration tests
- Pytest backend tests
- Physical Android-device validation for ML Kit translation and TTS

## 🧠 Architecture

```text
Image
→ on-device OCR
→ FastAPI backend
→ Groq structured extraction
→ deterministic safety/confidence validation
→ user review
→ medicine-reference lookup
→ plain-language explanation
→ English/Hindi/Telugu translation
→ Android TTS
```

The prescription image stays on the device. The extraction backend receives OCR text, while medicine-reference services receive only medicine identity information after confirmation. A reference lookup failure never blocks the confirmed prescription instructions. See [Architecture](docs/ARCHITECTURE.md) and [Safety](docs/SAFETY.md) for the detailed boundaries.

## 📁 Project structure

```text
medivoice/
├── app/                  # Flutter Android application and tests
├── backend/              # FastAPI backend and tests
├── docs/                 # Product, architecture, API, safety, and testing docs
├── sample_data/          # Synthetic and anonymized OCR fixtures
├── .env.example          # Safe backend configuration template
└── README.md
```

## ⚙️ Setup & installation steps

### Prerequisites

- Flutter 3.47 stable with its bundled Dart SDK
- Android SDK 36 with an Android device or emulator (the app targets SDK 35)
- Python 3.12 or a compatible Python 3 release
- A Groq API key for live extraction; no key is needed for mock mode
- Internet access for live Groq/reference APIs and first-time Hindi/Telugu model downloads

Android Studio is optional; the Flutter and Android command-line tools are sufficient.

### Clone repository

```bash
git clone <REPOSITORY_URL>
cd medivoice
```

### Backend setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r backend/requirements.txt
```

Create the local environment file:

```bash
cp .env.example .env
```

For live Groq extraction, edit `.env` to contain:

```env
GROQ_API_KEY=your_groq_api_key
GROQ_MODEL=openai/gpt-oss-20b
DEMO_MODE=false
APP_ENV=development
LOG_LEVEL=INFO
API_REQUEST_TIMEOUT_SECONDS=15
REFERENCE_REQUEST_TIMEOUT_SECONDS=8
```

Keep the key on the backend only. To run without Groq, leave `GROQ_API_KEY` empty and set `DEMO_MODE=true`; the backend then accepts only recognized synthetic fixture patterns and fails closed for unknown input.

### Flutter setup

```bash
cd app
flutter pub get
```

## 🚀 How to run the project

Use three terminals for local physical-device development.

### Terminal 1 — backend

```bash
cd medivoice
source .venv/bin/activate
uvicorn backend.app.main:app --host 0.0.0.0 --port 8000
```

Confirm the service at `http://127.0.0.1:8000/healthz`.

### Find the Mac/local machine IP

On macOS:

```bash
ipconfig getifaddr en0
```

The Android phone and development machine must be on the same network. If the active network uses another interface, find that interface’s LAN address instead.

### Terminal 2 — Flutter app

```bash
cd app
flutter devices
```

Then run live mode:

```bash
flutter run -d <DEVICE_ID> \
  --dart-define=DEMO_MODE=false \
  --dart-define=API_BASE_URL=http://<LOCAL_IP>:8000
```

`<DEVICE_ID>` is the identifier shown by `flutter devices`; `<LOCAL_IP>` is the development machine’s reachable LAN address. Local HTTP is permitted only by the debug Android manifest.

For a key-free demonstration, keep the backend in `DEMO_MODE=true` and run Flutter with `--dart-define=DEMO_MODE=true`. Tap **Try synthetic demo** to exercise the normal API, safety review, explanation, translation, and TTS flow with synthetic data.

### Terminal 3 — optional phone mirroring

```bash
scrcpy --video-codec=h264
```

This is useful for development or demo recording, but is not required to run MediVoice.

## 🧪 Testing

Backend tests and compilation:

```bash
pip install -r backend/requirements-dev.txt
python -m compileall -q backend/app backend/tests
python -m pytest backend
```

Flutter formatting, analysis, and tests:

```bash
cd app
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Device integration tests require a connected Android device:

```bash
flutter test integration_test/full_workflow_test.dart -d <DEVICE_ID>
```

The default automated suites do not require a Groq key. See [Testing](docs/TESTING.md) for the full scenario matrix and manual platform checks.

## 🔒 Safety and privacy

- MediVoice is an accessibility and explanation tool, not a diagnostic or prescribing system.
- It never intentionally changes a prescribed dose or fills in missing instructions.
- Missing or uncertain critical information is surfaced for review.
- General medicine-reference information is visually separated from the doctor’s instructions.
- Prescription images remain on-device and active scan data is not persisted by MediVoice.
- OCR or patient data is not sent to RxNorm, DailyMed, or openFDA.
- API keys stay server-side and must never be committed.

## 🌐 External services

- **Groq:** converts OCR text into the validated extraction schema in live mode.
- **RxNorm:** normalizes confirmed medicine identities.
- **DailyMed:** preferred source for concise, supported drug-label facts.
- **openFDA:** fallback drug-label source when DailyMed has no usable result.

The public medicine-reference services receive medicine identity data only. Full endpoint details are in [API contract](docs/API_CONTRACT.md).

## ⚠️ Current limitations

- Handwriting OCR quality depends on image clarity, lighting, and layout.
- Input OCR currently supports Latin-script text only.
- Some medicine-reference lookups may be unavailable or have partial coverage.
- Hindi and Telugu wording depends on the on-device ML Kit models and may require a first-use download.
- TTS voice quality and availability depend on installed Android voices.
- Android is the current MVP target.
- Live extraction and reference lookup require network access.
- MediVoice is not a substitute for advice from a doctor or pharmacist.

Further detail is available in [Project specification](docs/PROJECT_SPEC.md), [Data schema](docs/DATA_SCHEMA.md), and [Known limitations](docs/LIMITATIONS.md).
