import pytest
from fastapi.testclient import TestClient

import backend.app.main as main_module
from backend.app.config import Settings


app = main_module.app


client = TestClient(app)


@pytest.fixture(autouse=True)
def force_live_mode_without_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        main_module,
        "settings",
        Settings(gemini_api_key="", demo_mode=False, _env_file=None),
    )


def test_healthz() -> None:
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_invalid_short_ocr_has_safe_error() -> None:
    response = client.post(
        "/api/v1/extractions",
        json={
            "schema_version": "1.0",
            "scan_mode": "prescription",
            "ocr_text": "???",
        },
    )
    assert response.status_code == 400
    body = response.json()
    assert body["error"]["code"] == "invalid_request"
    assert "ocr_text" not in str(body)


def test_invalid_mode_returns_bad_request() -> None:
    response = client.post(
        "/api/v1/extractions",
        json={
            "schema_version": "1.0",
            "scan_mode": "photo",
            "ocr_text": "Paracetamol 500 mg twice daily",
        },
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_request"


def test_structurally_incomplete_request_returns_unprocessable() -> None:
    response = client.post(
        "/api/v1/extractions",
        json={"schema_version": "1.0", "scan_mode": "prescription"},
    )
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "invalid_request"


def test_missing_api_key_fails_without_echoing_ocr() -> None:
    response = client.post(
        "/api/v1/extractions",
        json={
            "schema_version": "1.0",
            "scan_mode": "prescription",
            "ocr_text": "Paracetamol 500 mg twice daily",
        },
    )
    assert response.status_code == 503
    body = response.json()
    assert body["error"]["code"] == "model_unavailable"
    assert "Paracetamol" not in str(body)


def test_demo_mode_extracts_synthetic_text_without_api_key(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        main_module,
        "settings",
        Settings(gemini_api_key="", demo_mode=True, _env_file=None),
    )

    response = client.post(
        "/api/v1/extractions",
        json={
            "schema_version": "1.0",
            "scan_mode": "prescription",
            "ocr_text": (
                "Paracetamol 500 mg\n"
                "Take one tablet twice daily after meals for 5 days."
            ),
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["medicines"][0]["medicine_name"] == "Paracetamol"
    assert body["medicines"][0]["dose"] == "1 tablet"
    assert "deterministic synthetic fixture" in body["warnings"][0]


def test_demo_mode_still_applies_strip_safety(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        main_module,
        "settings",
        Settings(gemini_api_key="", demo_mode=True, _env_file=None),
    )

    response = client.post(
        "/api/v1/extractions",
        json={
            "schema_version": "1.0",
            "scan_mode": "medicine_strip",
            "ocr_text": (
                "CETIRIZINE HYDROCHLORIDE TABLETS IP\n"
                "10 mg\nDosage: As directed by the physician"
            ),
        },
    )

    assert response.status_code == 200
    medicine = response.json()["medicines"][0]
    assert medicine["medicine_name"] == "Cetirizine Hydrochloride"
    assert medicine["strength"] == "10 mg"
    assert medicine["dose"] is None
    assert medicine["frequency"] is None


def test_demo_mode_rejects_unknown_text_without_inventing_fields(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        main_module,
        "settings",
        Settings(gemini_api_key="", demo_mode=True, _env_file=None),
    )

    response = client.post(
        "/api/v1/extractions",
        json={
            "schema_version": "1.0",
            "scan_mode": "prescription",
            "ocr_text": "Completely unsupported synthetic medicine text",
        },
    )

    assert response.status_code == 502
    assert response.json()["error"]["code"] == "invalid_model_output"


def test_oversized_content_length_is_rejected() -> None:
    response = client.post(
        "/api/v1/extractions",
        content=b"{}",
        headers={"content-length": str(17 * 1024), "content-type": "application/json"},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_request"
