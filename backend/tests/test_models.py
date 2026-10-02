import pytest
from pydantic import ValidationError

from backend.app.models import (
    ExtractionRequest,
    ExtractionResponse,
    MedicineInstruction,
    ProviderExtractionPayload,
)


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


def test_provider_can_be_empty_while_public_success_contract_cannot() -> None:
    provider_payload = ProviderExtractionPayload(medicines=[])
    assert provider_payload.medicines == []
    assert provider_payload.warnings == []

    with pytest.raises(ValidationError):
        ExtractionResponse(request_id="request-1", medicines=[], warnings=[])
