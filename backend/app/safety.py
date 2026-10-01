from backend.app.models import ExtractionPayload, ScanMode


STRIP_WARNING = (
    "Dosage may not be available from this image. "
    "Check your prescription or pharmacist."
)


def apply_deterministic_safety(
    payload: ExtractionPayload,
    mode: ScanMode,
) -> ExtractionPayload:
    """Apply safety rules that must not depend on model compliance."""
    if mode is not ScanMode.MEDICINE_STRIP:
        return payload

    medicines = []
    for medicine in payload.medicines:
        warnings = list(dict.fromkeys([*medicine.warnings, STRIP_WARNING]))
        medicines.append(
            medicine.model_copy(
                update={
                    "dose": None,
                    "frequency": None,
                    "timing": None,
                    "duration": None,
                    "food_instruction": None,
                    "warnings": warnings,
                }
            )
        )

    return payload.model_copy(
        update={
            "medicines": medicines,
            "warnings": list(dict.fromkeys([*payload.warnings, STRIP_WARNING])),
        }
    )

