from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest

from backend.app.config import Settings
from backend.app.errors import (
    InvalidModelOutputError,
    NoMedicineDetectedError,
    ProviderServiceError,
)
from backend.app.groq_service import (
    GROQ_BASE_URL,
    MAX_COMPLETION_TOKENS,
    GroqExtractionService,
    strict_extraction_schema,
)
from backend.app.models import ScanMode


ROOT = Path(__file__).resolve().parents[2]
DEVICE_OCR_PATH = ROOT / "sample_data" / "fragmented_columns_device_ocr.txt"


VALID_JSON = """
{
  "medicines": [
    {
      "medicine_name": "Paracetamol",
      "strength": "500 mg",
      "dose": "1 tablet",
      "frequency": "Twice daily",
      "timing": null,
      "duration": "5 days",
      "food_instruction": "After meals",
      "route": null,
      "additional_instruction": null,
      "uncertain_fields": [],
      "warnings": []
    }
  ],
  "warnings": []
}
"""

MULTIPLE_MEDICINES_JSON = """
{
  "medicines": [
    {
      "medicine_name": "Paracetamol",
      "strength": "500 mg",
      "dose": "1 tablet",
      "frequency": "Twice daily",
      "timing": null,
      "duration": "5 days",
      "food_instruction": "After meals",
      "route": null,
      "additional_instruction": null,
      "uncertain_fields": [],
      "warnings": []
    },
    {
      "medicine_name": "Cetirizine",
      "strength": null,
      "dose": null,
      "frequency": "Once daily",
      "timing": "At bedtime",
      "duration": null,
      "food_instruction": null,
      "route": null,
      "additional_instruction": null,
      "uncertain_fields": ["dose", "duration"],
      "warnings": []
    }
  ],
  "warnings": []
}
"""

FRAGMENTED_COLUMNS_JSON = """
{
  "medicines": [
    {
      "medicine_name": "Paracetamol",
      "strength": "500 mg",
      "dose": "1 tablet",
      "frequency": "3 times daily",
      "timing": null,
      "duration": "5 days",
      "food_instruction": "after food",
      "route": null,
      "additional_instruction": null,
      "uncertain_fields": [],
      "warnings": []
    },
    {
      "medicine_name": "Azithromycin",
      "strength": "500 mg",
      "dose": "1 tablet",
      "frequency": "once daily",
      "timing": null,
      "duration": "3 days",
      "food_instruction": "after food",
      "route": null,
      "additional_instruction": null,
      "uncertain_fields": [],
      "warnings": []
    },
    {
      "medicine_name": "Cetirizine",
      "strength": "10 mg",
      "dose": "1 tablet",
      "frequency": null,
      "timing": "at night",
      "duration": "5 days",
      "food_instruction": null,
      "route": null,
      "additional_instruction": null,
      "uncertain_fields": [],
      "warnings": []
    },
    {
      "medicine_name": "Pantoprazole",
      "strength": "40 mg",
      "dose": "1 tablet",
      "frequency": "once daily",
      "timing": null,
      "duration": "5 days",
      "food_instruction": "before breakfast",
      "route": null,
      "additional_instruction": null,
      "uncertain_fields": [],
      "warnings": []
    },
    {
      "medicine_name": "Cough Syrup (Levosalbutamol + Ambroxol)",
      "strength": null,
      "dose": "10 ml",
      "frequency": "three times daily",
      "timing": null,
      "duration": "5 days",
      "food_instruction": null,
      "route": null,
      "additional_instruction": null,
      "uncertain_fields": [],
      "warnings": []
    }
  ],
  "warnings": []
}
"""


class FakeCompletions:
    def __init__(
        self,
        *,
        content: str | None = VALID_JSON,
        error: Exception | None = None,
        outcomes: list[str | None | Exception] | None = None,
    ):
        self.content = content
        self.error = error
        self.outcomes = list(outcomes) if outcomes is not None else None
        self.kwargs: dict[str, Any] | None = None
        self.calls: list[dict[str, Any]] = []

    def create(self, **kwargs: Any) -> Any:
        self.kwargs = kwargs
        self.calls.append(kwargs)
        outcome: str | None | Exception = self.error or self.content
        if self.outcomes is not None:
            if not self.outcomes:
                raise AssertionError("Unexpected extra provider call")
            outcome = self.outcomes.pop(0)
        if isinstance(outcome, Exception):
            raise outcome
        return SimpleNamespace(
            choices=[SimpleNamespace(message=SimpleNamespace(content=outcome))]
        )


class FakeClient:
    def __init__(self, completions: FakeCompletions):
        self.chat = SimpleNamespace(completions=completions)


class StatusError(Exception):
    def __init__(
        self,
        status_code: int,
        body: object | None = None,
        *,
        headers: dict[str, str] | None = None,
    ):
        self.status_code = status_code
        self.body = body
        self.response = SimpleNamespace(headers=headers or {})


def settings(**overrides: Any) -> Settings:
    return Settings(
        groq_api_key="test-key",
        groq_model="openai/gpt-oss-20b",
        demo_mode=False,
        _env_file=None,
        **overrides,
    )


def test_requests_strict_json_without_tools_and_validates_payload() -> None:
    completions = FakeCompletions()
    client = FakeClient(completions)
    client_args: dict[str, Any] = {}

    def client_factory(**kwargs: Any) -> FakeClient:
        client_args.update(kwargs)
        return client

    result = GroqExtractionService(
        settings(), client_factory=client_factory
    ).extract(
        ScanMode.PRESCRIPTION,
        "Paracetamol 500 mg one tablet twice daily after meals for 5 days",
    )

    assert result.medicines[0].medicine_name == "Paracetamol"
    assert client_args["base_url"] == GROQ_BASE_URL
    assert client_args["api_key"] == "test-key"
    assert client_args["max_retries"] == 0
    assert completions.kwargs is not None
    assert completions.kwargs["model"] == "openai/gpt-oss-20b"
    assert completions.kwargs["reasoning_effort"] == "low"
    assert completions.kwargs["max_completion_tokens"] == MAX_COMPLETION_TOKENS
    response_format = completions.kwargs["response_format"]
    assert response_format["type"] == "json_schema"
    assert response_format["json_schema"]["strict"] is True
    assert completions.kwargs["stream"] is False
    assert "tools" not in completions.kwargs
    assert "functions" not in completions.kwargs


def test_valid_strict_schema_response_with_nullable_fields() -> None:
    result = GroqExtractionService(
        settings(),
        client_factory=lambda **_: FakeClient(FakeCompletions()),
    ).extract(ScanMode.PRESCRIPTION, "Synthetic prescription OCR content")

    assert result.medicines[0].timing is None
    assert result.medicines[0].route is None
    assert result.medicines[0].additional_instruction is None


def test_valid_strict_schema_response_with_multiple_medicines() -> None:
    result = GroqExtractionService(
        settings(),
        client_factory=lambda **_: FakeClient(
            FakeCompletions(content=MULTIPLE_MEDICINES_JSON)
        ),
    ).extract(ScanMode.PRESCRIPTION, "Synthetic prescription with two medicines")

    assert [item.medicine_name for item in result.medicines] == [
        "Paracetamol",
        "Cetirizine",
    ]
    assert result.medicines[1].dose is None


def test_empty_medicines_becomes_deterministic_no_medicine_failure() -> None:
    service = GroqExtractionService(
        settings(),
        client_factory=lambda **_: FakeClient(
            FakeCompletions(content='{"medicines": [], "warnings": []}')
        ),
    )

    with pytest.raises(NoMedicineDetectedError) as caught:
        service.extract(ScanMode.PRESCRIPTION, "Unclear synthetic OCR content")

    assert caught.value.code == "no_medicine_detected"
    assert caught.value.status_code == 502


def test_omitted_warnings_are_normalized_to_empty_lists() -> None:
    content = """
    {
      "medicines": [
        {
          "medicine_name": "Paracetamol",
          "strength": "500 mg",
          "dose": null,
          "frequency": null,
          "timing": null,
          "duration": null,
          "food_instruction": null,
          "route": null,
          "additional_instruction": null,
          "uncertain_fields": []
        }
      ]
    }
    """
    result = GroqExtractionService(
        settings(),
        client_factory=lambda **_: FakeClient(FakeCompletions(content=content)),
    ).extract(ScanMode.PRESCRIPTION, "Paracetamol 500 mg synthetic OCR")

    assert result.warnings == []
    assert result.medicines[0].warnings == []


def test_fragmented_device_ocr_preserves_five_medicines_and_numbered_prompt() -> None:
    completions = FakeCompletions(content=FRAGMENTED_COLUMNS_JSON)
    source = DEVICE_OCR_PATH.read_text().rstrip("\n")
    result = GroqExtractionService(
        settings(),
        client_factory=lambda **_: FakeClient(completions),
    ).extract(ScanMode.PRESCRIPTION, source)

    assert completions.kwargs is not None
    prompt = completions.kwargs["messages"][0]["content"]
    assert "[L009] 1. Paracetamol 500 mg" in prompt
    assert "[L035] 10 ml three times daly" in prompt
    assert [medicine.medicine_name for medicine in result.medicines] == [
        "Paracetamol",
        "Azithromycin",
        "Cetirizine",
        "Pantoprazole",
        "Cough Syrup (Levosalbutamol + Ambroxol)",
    ]
    assert [medicine.duration for medicine in result.medicines] == [
        "5 days",
        "3 days",
        "5 days",
        "5 days",
        "5 days",
    ]
    assert result.medicines[2].frequency is None
    assert result.medicines[3].food_instruction == "before breakfast"


def test_empty_schema_padding_item_is_removed_without_changing_data() -> None:
    padded = MULTIPLE_MEDICINES_JSON.replace(
        '"medicine_name": "Cetirizine",', '"medicine_name": null,'
    ).replace('"frequency": "Once daily",', '"frequency": null,').replace(
        '"timing": "At bedtime",', '"timing": null,'
    ).replace(
        '"uncertain_fields": ["dose", "duration"]', '"uncertain_fields": []'
    )
    result = GroqExtractionService(
        settings(),
        client_factory=lambda **_: FakeClient(FakeCompletions(content=padded)),
    ).extract(ScanMode.PRESCRIPTION, "Synthetic prescription OCR content")

    assert len(result.medicines) == 1
    assert result.medicines[0].medicine_name == "Paracetamol"


def test_strict_schema_requires_all_fields_and_closes_objects() -> None:
    schema = strict_extraction_schema()
    medicine = schema["$defs"]["MedicineInstruction"]

    assert set(schema["required"]) == {"medicines", "warnings"}
    assert schema["additionalProperties"] is False
    assert set(medicine["required"]) == set(medicine["properties"])
    assert medicine["additionalProperties"] is False
    assert "default" not in medicine["properties"]["dose"]
    assert medicine["properties"]["dose"]["type"] == ["string", "null"]
    assert schema["properties"]["medicines"]["minItems"] == 0
    assert schema["properties"]["medicines"]["maxItems"] == 10

    def assert_all_objects_are_strict(node: object) -> None:
        if isinstance(node, list):
            for item in node:
                assert_all_objects_are_strict(item)
            return
        if not isinstance(node, dict):
            return
        if node.get("type") == "object":
            assert node["additionalProperties"] is False
            assert set(node["required"]) == set(node.get("properties", {}))
        for value in node.values():
            assert_all_objects_are_strict(value)

    assert_all_objects_are_strict(schema)


@pytest.mark.parametrize("content", [None, "", "not json", "{}"])
def test_missing_or_malformed_output_fails_closed(content: str | None) -> None:
    service = GroqExtractionService(
        settings(),
        client_factory=lambda **_: FakeClient(FakeCompletions(content=content)),
    )

    with pytest.raises(InvalidModelOutputError):
        service.extract(ScanMode.PRESCRIPTION, "Synthetic OCR text with enough content")


def test_missing_key_fails_before_creating_client() -> None:
    created = False

    def client_factory(**_: Any) -> FakeClient:
        nonlocal created
        created = True
        return FakeClient(FakeCompletions())

    service = GroqExtractionService(
        Settings(groq_api_key="", demo_mode=False, _env_file=None),
        client_factory=client_factory,
    )

    with pytest.raises(ProviderServiceError) as caught:
        service.extract(ScanMode.PRESCRIPTION, "Synthetic OCR text with enough content")

    assert caught.value.status_code == 503
    assert created is False


def test_strict_schema_failure_uses_one_json_object_fallback() -> None:
    strict_error = StatusError(
        400,
        {"error": {"code": "json_validate_failed", "message": "invalid JSON"}},
    )
    completions = FakeCompletions(outcomes=[strict_error, VALID_JSON])
    result = GroqExtractionService(
        settings(), client_factory=lambda **_: FakeClient(completions)
    ).extract(ScanMode.PRESCRIPTION, "Paracetamol synthetic OCR content")

    assert result.medicines[0].medicine_name == "Paracetamol"
    assert len(completions.calls) == 2
    assert completions.calls[0]["response_format"]["type"] == "json_schema"
    assert completions.calls[1]["response_format"] == {"type": "json_object"}
    assert "tools" not in completions.calls[1]
    assert "functions" not in completions.calls[1]


def test_strict_and_fallback_failure_stops_after_two_calls() -> None:
    strict_error = StatusError(
        400,
        {"error": {"code": "json_validate_failed", "message": "invalid JSON"}},
    )
    fallback_error = StatusError(
        400,
        {"error": {"code": "json_validate_failed", "message": "still invalid"}},
    )
    completions = FakeCompletions(outcomes=[strict_error, fallback_error])
    service = GroqExtractionService(
        settings(), client_factory=lambda **_: FakeClient(completions)
    )

    with pytest.raises(InvalidModelOutputError):
        service.extract(ScanMode.PRESCRIPTION, "Synthetic OCR text with enough content")

    assert len(completions.calls) == 2


def test_rate_limit_maps_without_retry_storm_and_preserves_retry_after() -> None:
    completions = FakeCompletions(
        error=StatusError(429, headers={"retry-after": "7"})
    )
    client_args: dict[str, Any] = {}

    def client_factory(**kwargs: Any) -> FakeClient:
        client_args.update(kwargs)
        return FakeClient(completions)

    service = GroqExtractionService(
        settings(),
        client_factory=client_factory,
    )

    with pytest.raises(ProviderServiceError) as caught:
        service.extract(ScanMode.PRESCRIPTION, "Synthetic OCR text with enough content")

    assert caught.value.code == "rate_limited"
    assert caught.value.status_code == 429
    assert caught.value.retryable is True
    assert caught.value.retry_after == "7"
    assert len(completions.calls) == 1
    assert client_args["max_retries"] == 0


def test_http_400_logs_sanitized_provider_detail(
    caplog: pytest.LogCaptureFixture,
) -> None:
    ocr_text = "Private patient OCR Paracetamol 500 mg"
    error = StatusError(
        400,
        {
            "error": {
                "message": "Schema rejected for strict mode",
                "type": "invalid_request_error",
                "code": "json_schema_invalid",
                "failed_generation": ocr_text,
            }
        },
    )
    service = GroqExtractionService(
        settings(),
        client_factory=lambda **_: FakeClient(FakeCompletions(error=error)),
    )

    with caplog.at_level("WARNING", logger="medivoice.groq"):
        with pytest.raises(ProviderServiceError):
            service.extract(ScanMode.PRESCRIPTION, ocr_text)

    assert "Schema rejected for strict mode" in caplog.text
    assert "json_schema_invalid" in caplog.text
    assert ocr_text not in caplog.text
    assert "test-key" not in caplog.text


def test_invalid_output_logs_only_validation_path_and_type(
    caplog: pytest.LogCaptureFixture,
) -> None:
    patient_text = "Private medicine content"
    service = GroqExtractionService(
        settings(),
        client_factory=lambda **_: FakeClient(
            FakeCompletions(content='{"medicines": [{"medicine_name": 42}]}')
        ),
    )

    with caplog.at_level("WARNING", logger="medivoice.groq"):
        with pytest.raises(InvalidModelOutputError):
            service.extract(ScanMode.PRESCRIPTION, patient_text)

    assert '"path":"medicines.0.medicine_name"' in caplog.text
    assert '"type":"string_type"' in caplog.text
    assert patient_text not in caplog.text
    assert "42" not in caplog.text
