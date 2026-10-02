# Known Limitations

1. Handwritten prescriptions may be difficult or impossible to recognize.
2. OCR accuracy depends on image quality, lighting, focus, font, layout, and language.
3. MVP input OCR supports Latin characters only.
4. Medicine strips may not contain patient-specific dosage instructions.
5. Translation can alter nuance or pronunciation.
6. TTS quality and language availability depend on installed device voices.
7. AI structured extraction is not guaranteed to be correct even when JSON is valid.
8. MediVoice does not diagnose or prescribe.
9. It does not validate whether a prescription is medically correct.
10. It does not detect every medicine interaction.
11. It does not replace a doctor or pharmacist.
12. Output languages are initially limited to English, Hindi, and Telugu.
13. Internet is required for live Groq extraction and first-time translation-model download.
14. Medicine reference information is limited to label-supported common uses, explicitly common side effects, and one general caution. It is not personalized advice, indication inference, interaction checking, suitability analysis, or a substitute for a pharmacist.
15. RxNorm, DailyMed, and openFDA availability and label wording vary. Ambiguous or unmatched names deliberately show no reference facts; some matched medicines may have partial or unavailable About content.
16. The Android-only MVP has no iOS or web client.
17. Scans are not saved; leaving the active flow loses the result.
18. The unauthenticated Cloud Run demo endpoint is vulnerable to discovery and abuse; quotas limit cost but do not provide production access control.
19. Low-resolution detection is heuristic and does not reliably detect blur.
20. Demo mode recognizes only bundled synthetic fixture patterns; it is not a substitute for live extraction and rejects unsupported text.
