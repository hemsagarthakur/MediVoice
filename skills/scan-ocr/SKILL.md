---
name: scan-ocr
description: Change MediVoice Android image acquisition, preparation, or ML Kit OCR behavior without weakening privacy or safe failure handling.
---

# MediVoice Scan and OCR

Read `AGENTS.md`, `docs/ARCHITECTURE.md`, and `docs/TESTING.md`.

The accepted input is one temporary local image from camera or gallery. `ImageInputService` owns picker/crop behavior; `OcrService` owns decode checks, the low-resolution warning, Latin ML Kit recognition, and native resource cleanup.

Preserve line breaks and keep OCR text only in active memory. Never upload an image, write permanent copies, log recognized text, or continue when OCR contains fewer than eight alphanumeric characters. Treat low resolution as a warning with rescan/continue choice, not proof of unreadability.

Use service fakes for automated tests and complete a real Android-device smoke test after plugin or manifest changes.

