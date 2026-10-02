import json
import re
from collections import OrderedDict
from dataclasses import dataclass
from difflib import SequenceMatcher
from html import unescape
from threading import Lock
from typing import Protocol
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from xml.etree import ElementTree

from backend.app.models import MedicineReference

RXNORM_BASE = "https://rxnav.nlm.nih.gov/REST"
DAILYMED_BASE = "https://dailymed.nlm.nih.gov/dailymed/services/v2"
OPENFDA_LABEL_URL = "https://api.fda.gov/drug/label.json"


class ReferenceHttpClient(Protocol):
    def get_json(self, url: str, params: dict[str, str]) -> dict: ...

    def get_text(self, url: str, params: dict[str, str] | None = None) -> str: ...


class UrlLibReferenceHttpClient:
    def __init__(self, timeout_seconds: float) -> None:
        self._timeout_seconds = timeout_seconds

    def _read(self, url: str, params: dict[str, str] | None = None) -> bytes:
        target = f"{url}?{urlencode(params)}" if params else url
        request = Request(target, headers={"User-Agent": "MediVoice/1.0"})
        with urlopen(request, timeout=self._timeout_seconds) as response:
            return response.read()

    def get_json(self, url: str, params: dict[str, str]) -> dict:
        return json.loads(self._read(url, params))

    def get_text(self, url: str, params: dict[str, str] | None = None) -> str:
        return self._read(url, params).decode("utf-8", errors="replace")


@dataclass(frozen=True)
class _Match:
    canonical_name: str
    rx_cui: str
    quality: str


class MedicineReferenceService:
    def __init__(
        self,
        client: ReferenceHttpClient,
        *,
        cache_size: int = 128,
    ) -> None:
        self._client = client
        self._cache_size = cache_size
        self._cache: OrderedDict[str, MedicineReference] = OrderedDict()
        self._cache_lock = Lock()

    def lookup(self, medicine_name: str, *, name_uncertain: bool) -> MedicineReference:
        requested = medicine_name.strip()
        key = _normalize_name(requested)
        if name_uncertain:
            return self._unavailable(requested, "ambiguous")
        with self._cache_lock:
            cached = self._cache.get(key)
            if cached is not None:
                self._cache.move_to_end(key)
                return cached.model_copy(update={"requested_name": requested})
        try:
            match = self._match_name(requested)
            if match is None:
                result = self._unavailable(requested, "none")
            else:
                result = self._lookup_label(requested, match)
        except Exception:
            return self._unavailable(requested, "none")
        with self._cache_lock:
            self._cache[key] = result
            if len(self._cache) > self._cache_size:
                self._cache.popitem(last=False)
        return result

    def _match_name(self, requested: str) -> _Match | None:
        exact = self._client.get_json(
            f"{RXNORM_BASE}/rxcui.json", {"name": requested, "search": "2"}
        )
        ids = exact.get("idGroup", {}).get("rxnormId", [])
        if len(ids) > 1:
            return None
        if len(ids) == 1:
            properties = self._properties(str(ids[0]))
            if properties is not None:
                return _Match(properties[0], properties[1], "exact")

        if any(marker in requested for marker in ("+", "/", "&")):
            return None
        approximate = self._client.get_json(
            f"{RXNORM_BASE}/approximateTerm.json",
            {"term": requested, "maxEntries": "5", "option": "1"},
        )
        candidates: list[tuple[float, str, str]] = []
        seen: set[str] = set()
        for raw in approximate.get("approximateGroup", {}).get("candidate", []):
            rx_cui = str(raw.get("rxcui", ""))
            if not rx_cui or rx_cui in seen:
                continue
            seen.add(rx_cui)
            properties = self._properties(rx_cui)
            if properties is None:
                continue
            canonical, canonical_id = properties
            similarity = SequenceMatcher(
                None, _normalize_name(requested), _normalize_name(canonical)
            ).ratio()
            candidates.append((similarity, canonical, canonical_id))
        candidates.sort(reverse=True)
        if not candidates or candidates[0][0] < 0.82:
            return None
        if len(candidates) > 1 and candidates[0][0] - candidates[1][0] < 0.10:
            return None
        best = candidates[0]
        return _Match(best[1], best[2], "normalized")

    def _properties(self, rx_cui: str) -> tuple[str, str] | None:
        body = self._client.get_json(
            f"{RXNORM_BASE}/rxcui/{rx_cui}/properties.json", {}
        )
        properties = body.get("properties")
        if not isinstance(properties, dict) or not properties.get("name"):
            return None
        return str(properties["name"]), str(properties.get("rxcui", rx_cui))

    def _lookup_label(self, requested: str, match: _Match) -> MedicineReference:
        dailymed = self._from_dailymed(requested, match)
        if dailymed is not None:
            return dailymed
        openfda = self._from_openfda(requested, match)
        if openfda is not None:
            return openfda
        return MedicineReference(
            requested_name=requested,
            canonical_name=match.canonical_name,
            rx_cui=match.rx_cui,
            match_quality=match.quality,
            available=False,
        )

    def _from_dailymed(
        self, requested: str, match: _Match
    ) -> MedicineReference | None:
        body = self._client.get_json(
            f"{DAILYMED_BASE}/spls.json",
            {"rxcui": match.rx_cui, "pagesize": "100"},
        )
        labels = body.get("data", [])
        canonical = _normalize_name(match.canonical_name)
        suitable = [
            label
            for label in labels
            if _normalize_name(str(label.get("title", ""))).startswith(canonical)
            and " and " not in _normalize_name(str(label.get("title", "")))
        ]
        if not suitable:
            return None
        label = suitable[0]
        set_id = str(label.get("setid", ""))
        if not set_id:
            return None
        xml = self._client.get_text(f"{DAILYMED_BASE}/spls/{set_id}.xml")
        sections = _xml_sections(xml)
        facts = _facts_from_sections(sections)
        if not any(facts):
            return None
        return MedicineReference(
            requested_name=requested,
            canonical_name=match.canonical_name,
            rx_cui=match.rx_cui,
            commonly_used_for=facts[0],
            common_side_effects=facts[1],
            important_caution=facts[2],
            source="dailymed",
            source_reference=f"https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid={set_id}",
            match_quality=match.quality,
            available=True,
        )

    def _from_openfda(
        self, requested: str, match: _Match
    ) -> MedicineReference | None:
        body = self._client.get_json(
            OPENFDA_LABEL_URL,
            {
                "search": f'openfda.generic_name.exact:"{match.canonical_name}"',
                "limit": "5",
            },
        )
        for label in body.get("results", []):
            generic_names = label.get("openfda", {}).get("generic_name", [])
            if not any(
                _normalize_name(name) == _normalize_name(match.canonical_name)
                for name in generic_names
            ):
                continue
            sections = {
                "indications and usage": " ".join(label.get("indications_and_usage", [])),
                "purpose": " ".join(label.get("purpose", [])),
                "adverse reactions": " ".join(label.get("adverse_reactions", [])),
                "warnings and precautions": " ".join(
                    label.get("warnings_and_cautions", label.get("warnings", []))
                ),
            }
            facts = _facts_from_sections(sections)
            if not any(facts):
                continue
            return MedicineReference(
                requested_name=requested,
                canonical_name=match.canonical_name,
                rx_cui=match.rx_cui,
                commonly_used_for=facts[0],
                common_side_effects=facts[1],
                important_caution=facts[2],
                source="openfda",
                source_reference=OPENFDA_LABEL_URL,
                match_quality=match.quality,
                available=True,
            )
        return None

    @staticmethod
    def _unavailable(requested: str, quality: str) -> MedicineReference:
        return MedicineReference(
            requested_name=requested,
            match_quality=quality,
            available=False,
        )


def _normalize_name(value: str) -> str:
    return " ".join(re.sub(r"[^a-z0-9]+", " ", value.casefold()).split())


def _xml_sections(xml: str) -> dict[str, str]:
    root = ElementTree.fromstring(xml)
    sections: dict[str, str] = {}
    for section in root.iter():
        if section.tag.rsplit("}", 1)[-1] != "section":
            continue
        title = next(
            (
                " ".join(child.itertext()).strip()
                for child in section
                if child.tag.rsplit("}", 1)[-1] == "title"
            ),
            "",
        )
        if title:
            sections[title.casefold()] = " ".join(section.itertext())
    return sections


def _clean(value: str) -> str:
    value = unescape(re.sub(r"<[^>]+>", " ", value))
    return " ".join(value.replace("•", ". ").split())


def _sentences(value: str) -> list[str]:
    return [part.strip(" .:-") for part in re.split(r"(?<=[.!?])\s+", _clean(value)) if len(part.strip()) > 8]


def _facts_from_sections(
    sections: dict[str, str],
) -> tuple[list[str], list[str], str | None]:
    uses_text = " ".join(
        text
        for title, text in sections.items()
        if "indications and usage" in title or title == "uses" or title == "purpose"
    )
    clean_uses = _clean(uses_text)
    lower_uses = clean_uses.casefold()
    uses: list[str]
    if "reduce" in lower_uses and "fever" in lower_uses and "relieve" in lower_uses and "pain" in lower_uses:
        uses = ["reducing fever", "relieving minor aches and pains"]
    elif "bacterial" in lower_uses and (
        "indicated" in lower_uses or "used" in lower_uses
    ):
        uses = ["treating certain bacterial infections"]
    else:
        uses = []
    for sentence in _sentences(uses_text) if not uses else []:
        simplified = re.sub(
            r"^(?:\d+(?:\.\d+)?\s+)?(?:INDICATIONS AND USAGE|USES|PURPOSE)\s*",
            "",
            sentence,
            flags=re.I,
        )
        if simplified and len(simplified) <= 240:
            uses.append(simplified)
        if len(uses) == 1:
            break

    adverse_text = " ".join(
        text for title, text in sections.items() if "adverse reactions" in title
    )
    side_effects: list[str] = []
    common = re.search(
        r"(?:most common|common) (?:treatment-related )?(?:adverse reactions|side effects)(?: are| were| include|:)\s*([^.]*)",
        _clean(adverse_text),
        flags=re.I,
    )
    if common:
        raw_items = re.sub(r"\([^)]*%[^)]*\)", "", common.group(1))
        for item in re.split(r",|\bor\b|\band\b", raw_items):
            cleaned = re.sub(r"\([^)]*\)", "", item).strip(" .;:")
            if cleaned and len(cleaned) <= 80:
                side_effects.append(cleaned)
            if len(side_effects) == 3:
                break

    warning_text = " ".join(
        text
        for title, text in sections.items()
        if title == "warnings" or "warnings and precautions" in title
    )
    caution = None
    warning_sentences = _sentences(warning_text)
    priorities = (
        "do not exceed",
        "stop use and seek",
        "discontinue",
        "serious allergic",
        "severe liver damage",
    )
    ordered = sorted(
        enumerate(warning_sentences),
        key=lambda entry: (
            min(
                (
                    index
                    for index, phrase in enumerate(priorities)
                    if phrase in entry[1].casefold()
                ),
                default=len(priorities),
            ),
            entry[0],
        ),
    )
    for _, sentence in ordered:
        simplified = re.sub(
            r"^\d+(?:\.\d+)?\s+WARNINGS(?: AND PRECAUTIONS)?\s*",
            "",
            sentence,
            flags=re.I,
        )
        simplified = re.sub(r"\b(?:your child|the child)\b", "you", simplified, flags=re.I)
        lowered = simplified.casefold()
        if "do not exceed" in lowered:
            simplified = "Do not take more than the recommended amount"
        elif "allergic" in lowered and (
            "discontinue" in lowered or "stop" in lowered
        ):
            simplified = "Stop using this medicine if an allergic reaction occurs"
        simplified = re.sub(r"\(\s*\d+(?:\.\d+)?\s*\)", "", simplified)
        simplified = " ".join(simplified.split()).strip(" .;:")
        if simplified and len(simplified) <= 120:
            caution = simplified
            break
    uses = [value for value in uses if len(value) <= 100][:1]
    side_effects = [value for value in side_effects if len(value) <= 50][:3]
    return uses, side_effects, caution
