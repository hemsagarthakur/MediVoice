from backend.app.errors import InvalidModelOutputError
from backend.app.models import (
    ExtractionPayload,
    MedicineField,
    MedicineInstruction,
    ScanMode,
)


DEMO_WARNING = (
    "Demo mode used a deterministic synthetic fixture. "
    "Verify every field before continuing."
)


class MockExtractionService:
    """Return grounded results only for the repository's synthetic demo text."""

    def extract(self, mode: ScanMode, ocr_text: str) -> ExtractionPayload:
        normalized = " ".join(ocr_text.casefold().split())

        if mode is ScanMode.MEDICINE_STRIP:
            return self._extract_strip(normalized)
        return self._extract_prescription(normalized)

    def _extract_prescription(self, text: str) -> ExtractionPayload:
        if all(
            marker in text
            for marker in ("paracetamol 500 mg", "pantoprazole 40 mg", "cetirizine 10 mg")
        ):
            return ExtractionPayload(
                medicines=[
                    MedicineInstruction(
                        medicine_name="Paracetamol",
                        strength="500 mg",
                        dose="1 tablet",
                        frequency="Twice daily",
                        duration="3 days",
                    ),
                    MedicineInstruction(
                        medicine_name="Pantoprazole",
                        strength="40 mg",
                        dose="1 tablet",
                        frequency="Once daily",
                        timing="Before breakfast",
                        duration="5 days",
                    ),
                    MedicineInstruction(
                        medicine_name="Cetirizine",
                        strength="10 mg",
                        dose="1 tablet",
                        timing="At night",
                        duration="5 days",
                    ),
                ],
                warnings=[DEMO_WARNING],
            )

        if "amoxicillin 500 mg" in text and "paracetamol 500 mg" in text:
            return ExtractionPayload(
                medicines=[
                    MedicineInstruction(
                        medicine_name="Amoxicillin",
                        strength="500 mg",
                        dose="1 capsule",
                        frequency="Three times daily",
                        duration="5 days",
                        food_instruction="After food",
                    ),
                    MedicineInstruction(
                        medicine_name="Paracetamol",
                        strength="500 mg",
                        dose="1 tablet",
                        timing="When needed for fever",
                        uncertain_fields=[MedicineField.FREQUENCY],
                    ),
                ],
                warnings=[DEMO_WARNING],
            )

        if "azithromycin 500 mg" in text and "1? tablet" in text:
            return ExtractionPayload(
                medicines=[
                    MedicineInstruction(
                        medicine_name="Azithromycin",
                        strength="500 mg",
                        dose="1 tablet",
                        frequency="Once daily",
                        duration="3 days",
                        uncertain_fields=[MedicineField.DOSE],
                    )
                ],
                warnings=[DEMO_WARNING],
            )

        if "paracetamol 500 mg" in text and "twice daily" in text:
            return ExtractionPayload(
                medicines=[
                    MedicineInstruction(
                        medicine_name="Paracetamol",
                        strength="500 mg",
                        dose="1 tablet",
                        frequency="Twice daily",
                        duration="5 days" if "5 days" in text else None,
                        food_instruction=(
                            "After meals"
                            if "after meals" in text
                            else "After food" if "after food" in text else None
                        ),
                    )
                ],
                warnings=[DEMO_WARNING],
            )

        raise InvalidModelOutputError()

    def _extract_strip(self, text: str) -> ExtractionPayload:
        if "cetirizine" in text and "10 mg" in text:
            return ExtractionPayload(
                medicines=[
                    MedicineInstruction(
                        medicine_name="Cetirizine Hydrochloride",
                        strength="10 mg",
                    )
                ],
                warnings=[DEMO_WARNING],
            )
        if "azithromycin" in text and "500 mg" in text:
            return ExtractionPayload(
                medicines=[
                    MedicineInstruction(
                        medicine_name="Azithromycin",
                        strength="500 mg",
                    )
                ],
                warnings=[DEMO_WARNING],
            )
        raise InvalidModelOutputError()
