# Data Schema

## Enumerations

`ScanMode`: `prescription`, `medicine_strip`.

`MedicineField`: `medicine_name`, `strength`, `dose`, `frequency`, `timing`, `duration`, `food_instruction`, `route`, `additional_instruction`.

`AppLanguage`: English (`en`), Hindi (`hi`), Telugu (`te`).

## MedicineInstruction

Nine nullable strings represent only information visible in OCR text: medicine name, strength, dose, frequency, timing, duration, food instruction, route, and additional instruction. `uncertain_fields` is a unique set of `MedicineField`. `warnings` is a list of short displayable cautions. Strings are trimmed, limited to 200 characters, and normalized to null when blank or equivalent to unknown.

## ScanResult

- `mode`: scan mode.
- `sourceText`: exact OCR text, held only in active Flutter memory.
- `medicines`: one to ten medicine instructions.
- `warnings`: scan-level warnings.

The API does not echo `sourceText`; Flutter combines its local OCR text with the extraction response.

## TranslationResult

- `language`: selected language.
- `verifiedEnglishText`: deterministic text built after confirmation.
- `translatedText`: final translated text, or English when English is selected.
- `usedFallback`: true only when the caller intentionally displays English after a translation failure; audio remains disabled until the failure is acknowledged or retried.

## AppError

Contains a typed code, safe user message, retryable flag, and optional debug-only cause. Codes cover permission, image decode/quality, OCR, empty OCR, network, timeout, API response, invalid extraction, translation, speech, and unknown failures.

## Contract ownership

`docs/API_CONTRACT.md` owns the wire format. `backend/app/models.py` and Flutter model parsers implement it. Any change must update both sides and their fixture tests in one change.

