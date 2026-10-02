from backend.app.models import ExtractionPayload, MedicineInstruction, ScanMode
from backend.app.safety import STRIP_WARNING, apply_deterministic_safety


def test_strip_safety_removes_patient_instructions() -> None:
    payload = ExtractionPayload(
        medicines=[
            MedicineInstruction(
                medicine_name="Cetirizine",
                strength="10 mg",
                dose="1 tablet",
                frequency="Once daily",
                food_instruction="After food",
            )
        ]
    )

    result = apply_deterministic_safety(payload, ScanMode.MEDICINE_STRIP)

    assert result.medicines[0].dose is None
    assert result.medicines[0].frequency is None
    assert result.medicines[0].food_instruction is None
    assert STRIP_WARNING in result.warnings
    assert STRIP_WARNING in result.medicines[0].warnings


def test_prescription_safety_preserves_extracted_fields() -> None:
    payload = ExtractionPayload(
        medicines=[MedicineInstruction(medicine_name="Paracetamol", dose="1 tablet")]
    )
    assert apply_deterministic_safety(payload, ScanMode.PRESCRIPTION) == payload
