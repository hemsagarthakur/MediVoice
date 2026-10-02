# Synthetic sample data

The synthetic fixtures contain no patient identity or real patient records. They exercise clear, incomplete, ambiguous, multi-medicine, strip-only, OCR-failure, abbreviation, route, suspicious-dose, and malformed-model behavior. Add only synthetic or fully anonymized inputs unless the user explicitly provides and requests an exact device-captured regression fixture.

`fragmented_columns_device_ocr.txt` is the exact line-ordered OCR text explicitly supplied for this regression. It intentionally retains the provided spelling mistakes and fragmented column order. Do not use it outside this local test repository.

The text fixtures represent synthetic OCR output rather than medical advice. `malformed_model_response.json` is a deliberately invalid provider response used to verify fail-closed parsing.

In `DEMO_MODE=true`, deterministic extraction recognizes the patterns in `clear_single.txt`, `multiple_medicines.txt`, `three_medicines.txt`, `ambiguous_dose.txt`, `medicine_strip_missing_dose.txt`, and `strip_packaging_only.txt`. The remaining fixtures exercise failure, safety, and future live-evaluation cases; demo mode intentionally rejects unsupported text rather than guessing.
