import pytest
from pydantic import ValidationError

from backend.app.models import ExtractionRequest, MedicineInstruction


def test_nullable_text_normalizes_unknown_values() -> None:
    medicine = MedicineInstruction(
        medicine_name=" Paracetamol ", dose="unknown", duration="Not detected"
    )
    assert medicine.medicine_name == "Paracetamol"
    assert medicine.dose is None
    assert medicine.duration is None


def test_uncertain_fields_are_unique() -> None:
    medicine = MedicineInstruction(uncertain_fields=["dose", "dose", "frequency"])
    assert [field.value for field in medicine.uncertain_fields] == [
        "dose",
        "frequency",
    ]


def test_effectively_empty_ocr_is_rejected() -> None:
    with pytest.raises(ValidationError):
        ExtractionRequest(scan_mode="prescription", ocr_text=" -- ?? ")

