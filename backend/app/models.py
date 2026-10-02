from enum import StrEnum
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


SCHEMA_VERSION = "1.0"


class ScanMode(StrEnum):
    PRESCRIPTION = "prescription"
    MEDICINE_STRIP = "medicine_strip"


class MedicineField(StrEnum):
    MEDICINE_NAME = "medicine_name"
    STRENGTH = "strength"
    DOSE = "dose"
    FREQUENCY = "frequency"
    TIMING = "timing"
    DURATION = "duration"
    FOOD_INSTRUCTION = "food_instruction"
    ROUTE = "route"
    ADDITIONAL_INSTRUCTION = "additional_instruction"


NullableText = Annotated[str | None, Field(default=None, max_length=200)]
WarningText = Annotated[str, Field(min_length=1, max_length=240)]


class MedicineInstruction(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    medicine_name: NullableText = None
    strength: NullableText = None
    dose: NullableText = None
    frequency: NullableText = None
    timing: NullableText = None
    duration: NullableText = None
    food_instruction: NullableText = None
    route: NullableText = None
    additional_instruction: NullableText = None
    uncertain_fields: list[MedicineField] = Field(default_factory=list, max_length=9)
    warnings: list[WarningText] = Field(
        default_factory=list,
        max_length=10,
    )

    @field_validator(
        "medicine_name",
        "strength",
        "dose",
        "frequency",
        "timing",
        "duration",
        "food_instruction",
        "route",
        "additional_instruction",
        mode="before",
    )
    @classmethod
    def normalize_nullable_text(cls, value: object) -> object:
        if value is None:
            return None
        if not isinstance(value, str):
            return value
        normalized = value.strip()
        if normalized.casefold() in {
            "",
            "unknown",
            "not detected",
            "not available",
            "n/a",
            "null",
        }:
            return None
        return normalized

    @field_validator("uncertain_fields")
    @classmethod
    def unique_uncertain_fields(
        cls, fields: list[MedicineField]
    ) -> list[MedicineField]:
        return list(dict.fromkeys(fields))


class ExtractionPayload(BaseModel):
    model_config = ConfigDict(extra="forbid")

    medicines: list[MedicineInstruction] = Field(min_length=1, max_length=10)
    warnings: list[WarningText] = Field(
        default_factory=list,
        max_length=10,
    )


class ProviderExtractionPayload(BaseModel):
    """Provider-only envelope that can safely express no detected medicine.

    Successful API responses still use ``ExtractionPayload`` and therefore retain
    the public one-to-ten medicine contract.
    """

    model_config = ConfigDict(extra="forbid")

    medicines: list[MedicineInstruction] = Field(min_length=0, max_length=10)
    warnings: list[WarningText] = Field(default_factory=list, max_length=10)


class ExtractionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    schema_version: Literal["1.0"] = SCHEMA_VERSION
    scan_mode: ScanMode
    ocr_text: str = Field(min_length=1, max_length=12_000)

    @field_validator("ocr_text")
    @classmethod
    def reject_effectively_empty_ocr(cls, value: str) -> str:
        if sum(character.isalnum() for character in value) < 8:
            raise ValueError("ocr_text must contain at least 8 alphanumeric characters")
        return value


class ExtractionResponse(ExtractionPayload):
    schema_version: Literal["1.0"] = SCHEMA_VERSION
    request_id: str


class ApiErrorDetail(BaseModel):
    code: str
    message: str
    retryable: bool
    request_id: str


class ApiErrorResponse(BaseModel):
    error: ApiErrorDetail


class MedicineReferenceRequestItem(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    medicine_name: str = Field(min_length=1, max_length=200)
    name_uncertain: bool = False


class MedicineReferenceRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    schema_version: Literal["1.0"] = SCHEMA_VERSION
    medicines: list[MedicineReferenceRequestItem] = Field(min_length=1, max_length=10)


class MedicineReference(BaseModel):
    model_config = ConfigDict(extra="forbid")

    requested_name: str = Field(min_length=1, max_length=200)
    canonical_name: str | None = Field(default=None, max_length=200)
    rx_cui: str | None = Field(default=None, max_length=32)
    commonly_used_for: list[str] = Field(default_factory=list, max_length=3)
    common_side_effects: list[str] = Field(default_factory=list, max_length=4)
    important_caution: str | None = Field(default=None, max_length=300)
    source: Literal["dailymed", "openfda"] | None = None
    source_reference: str | None = Field(default=None, max_length=500)
    match_quality: Literal["exact", "normalized", "ambiguous", "none"]
    available: bool


class MedicineReferenceResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    schema_version: Literal["1.0"] = SCHEMA_VERSION
    request_id: str
    references: list[MedicineReference] = Field(min_length=1, max_length=10)
