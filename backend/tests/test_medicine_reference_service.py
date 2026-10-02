from backend.app.medicine_reference_service import MedicineReferenceService


LABEL_XML = """<?xml version="1.0"?>
<document xmlns="urn:hl7-org:v3"><component><structuredBody><component><section>
<title>INDICATIONS AND USAGE</title><text>Azithromycin is used to treat certain bacterial infections.</text>
</section></component><component><section><title>ADVERSE REACTIONS</title>
<text>Most common adverse reactions are diarrhea (5%), nausea (3%), abdominal pain (2%), or vomiting (2%).</text>
</section></component><component><section><title>WARNINGS AND PRECAUTIONS</title>
<text>Stop taking it and seek medical help if a serious allergic reaction occurs.</text>
</section></component></structuredBody></component></document>"""


class FakeClient:
    def __init__(self, *, exact: bool = True, ambiguous: bool = False) -> None:
        self.exact = exact
        self.ambiguous = ambiguous
        self.calls: list[tuple[str, dict[str, str]]] = []

    def get_json(self, url: str, params: dict[str, str]) -> dict:
        self.calls.append((url, params))
        if url.endswith("/rxcui.json"):
            return {"idGroup": {"rxnormId": ["18631"] if self.exact else []}}
        if "approximateTerm" in url:
            candidates = [
                {"rxcui": "18631"},
                *([{"rxcui": "999"}] if self.ambiguous else []),
            ]
            return {"approximateGroup": {"candidate": candidates}}
        if "/rxcui/18631/properties" in url:
            return {"properties": {"name": "Azithromycin", "rxcui": "18631"}}
        if "/rxcui/999/properties" in url:
            return {"properties": {"name": "Azithromycim", "rxcui": "999"}}
        if url.endswith("/spls.json"):
            return {
                "data": [
                    {
                        "setid": "label-id",
                        "title": "AZITHROMYCIN TABLET, FILM COATED",
                    }
                ]
            }
        raise AssertionError(url)

    def get_text(self, url: str, params: dict[str, str] | None = None) -> str:
        self.calls.append((url, params or {}))
        return LABEL_XML


def test_exact_match_extracts_supported_reference_facts() -> None:
    service = MedicineReferenceService(FakeClient())
    result = service.lookup("Azithromycin", name_uncertain=False)

    assert result.available is True
    assert result.canonical_name == "Azithromycin"
    assert result.rx_cui == "18631"
    assert result.match_quality == "exact"
    assert result.commonly_used_for == ["treating certain bacterial infections"]
    assert result.common_side_effects == [
        "diarrhea",
        "nausea",
        "abdominal pain",
    ]
    assert "allergic reaction" in (result.important_caution or "")
    assert result.source == "dailymed"


def test_strong_typo_can_use_normalized_match() -> None:
    service = MedicineReferenceService(FakeClient(exact=False))
    result = service.lookup("Azithromcyin", name_uncertain=False)
    assert result.available is True
    assert result.match_quality == "normalized"
    assert result.canonical_name == "Azithromycin"


def test_ambiguous_approximate_match_fails_closed() -> None:
    service = MedicineReferenceService(FakeClient(exact=False, ambiguous=True))
    result = service.lookup("Azithromcyin", name_uncertain=False)
    assert result.available is False
    assert result.match_quality == "none"


def test_uncertain_name_never_calls_reference_sources() -> None:
    client = FakeClient()
    result = MedicineReferenceService(client).lookup(
        "Levosalbutamdl + Ambroxdl", name_uncertain=True
    )
    assert result.available is False
    assert result.match_quality == "ambiguous"
    assert client.calls == []


def test_no_match_is_unavailable() -> None:
    class NoMatchClient(FakeClient):
        def get_json(self, url: str, params: dict[str, str]) -> dict:
            self.calls.append((url, params))
            if url.endswith("/rxcui.json"):
                return {"idGroup": {}}
            if "approximateTerm" in url:
                return {"approximateGroup": {}}
            raise AssertionError(url)

    result = MedicineReferenceService(NoMatchClient()).lookup(
        "Not A Medicine", name_uncertain=False
    )
    assert result.available is False


def test_source_failure_is_unavailable_and_does_not_raise() -> None:
    class BrokenClient(FakeClient):
        def get_json(self, url: str, params: dict[str, str]) -> dict:
            raise OSError("source unavailable")

    result = MedicineReferenceService(BrokenClient()).lookup(
        "Azithromycin", name_uncertain=False
    )
    assert result.available is False


def test_openfda_label_is_used_when_dailymed_has_no_suitable_label() -> None:
    class OpenFdaClient(FakeClient):
        def get_json(self, url: str, params: dict[str, str]) -> dict:
            if url.endswith("/spls.json"):
                return {"data": []}
            if "api.fda.gov" in url:
                return {
                    "results": [
                        {
                            "openfda": {"generic_name": ["Azithromycin"]},
                            "indications_and_usage": [
                                "Azithromycin is used to treat certain bacterial infections."
                            ],
                            "adverse_reactions": [
                                "Most common adverse reactions are nausea and diarrhea."
                            ],
                            "warnings_and_cautions": [
                                "Discontinue use if a serious allergic reaction occurs."
                            ],
                        }
                    ]
                }
            return super().get_json(url, params)

    result = MedicineReferenceService(OpenFdaClient()).lookup(
        "Azithromycin", name_uncertain=False
    )
    assert result.available is True
    assert result.source == "openfda"
    assert result.common_side_effects == ["nausea", "diarrhea"]


def test_cache_hit_avoids_repeating_external_calls() -> None:
    client = FakeClient()
    service = MedicineReferenceService(client)
    service.lookup("Azithromycin", name_uncertain=False)
    first_call_count = len(client.calls)
    service.lookup(" azithromycin ", name_uncertain=False)
    assert len(client.calls) == first_call_count
