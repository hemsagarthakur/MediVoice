import pytest

from backend.app.errors import InvalidModelOutputError
from backend.app.mock_extraction_service import MockExtractionService
from backend.app.models import MedicineField, ScanMode


service = MockExtractionService()


def test_extracts_all_medicines_from_synthetic_multi_medicine_fixture() -> None:
    result = service.extract(
        ScanMode.PRESCRIPTION,
        """
        Paracetamol 500 mg - 1 tablet twice daily for 3 days
        Pantoprazole 40 mg - 1 tablet once daily before breakfast for 5 days
        Cetirizine 10 mg - 1 tablet at night for 5 days
        """,
    )

    assert [medicine.medicine_name for medicine in result.medicines] == [
        "Paracetamol",
        "Pantoprazole",
        "Cetirizine",
    ]
    assert result.medicines[1].timing == "Before breakfast"


def test_ambiguous_synthetic_dose_remains_marked_uncertain() -> None:
    result = service.extract(
        ScanMode.PRESCRIPTION,
        "Azithromycin 500 mg\n1? tablet OD x 3 days",
    )

    medicine = result.medicines[0]
    assert medicine.dose == "1 tablet"
    assert MedicineField.DOSE in medicine.uncertain_fields


def test_unknown_demo_text_fails_closed() -> None:
    with pytest.raises(InvalidModelOutputError):
        service.extract(ScanMode.PRESCRIPTION, "Unknown demo input with no fixture")
