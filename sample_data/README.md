# Synthetic sample data

These 15 fixtures contain no patient identity or real patient records. They exercise clear, incomplete, ambiguous, multi-medicine, strip-only, OCR-failure, abbreviation, route, suspicious-dose, and malformed-model behavior. Add only synthetic or fully anonymized inputs.

The text fixtures represent synthetic OCR output rather than medical advice. `malformed_model_response.json` is a deliberately invalid provider response used to verify fail-closed parsing.

In `DEMO_MODE=true`, deterministic extraction recognizes the patterns in `clear_single.txt`, `multiple_medicines.txt`, `three_medicines.txt`, `ambiguous_dose.txt`, `medicine_strip_missing_dose.txt`, and `strip_packaging_only.txt`. The remaining fixtures exercise failure, safety, and future live-evaluation cases; demo mode intentionally rejects unsupported text rather than guessing.
