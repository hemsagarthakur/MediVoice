from pathlib import Path

from backend.app.models import ScanMode
from backend.app.prompt import build_layout_hints, build_prompt, number_ocr_lines


ROOT = Path(__file__).resolve().parents[2]
DEVICE_OCR_PATH = ROOT / "sample_data" / "fragmented_columns_device_ocr.txt"


def test_numbers_exact_fragmented_device_ocr_without_reordering_or_correction() -> None:
    source = DEVICE_OCR_PATH.read_text().rstrip("\n")
    numbered = number_ocr_lines(source)
    numbered_lines = numbered.splitlines()
    source_lines = source.splitlines()

    assert len(numbered_lines) == len(source_lines) == 44
    assert numbered_lines[0] == "[L001] Date:"
    assert numbered_lines[8] == "[L009] 1. Paracetamol 500 mg"
    assert numbered_lines[10] == "[L011] 2. Azithromycin 5o0 mg"
    assert numbered_lines[16] == (
        "[L017] 5. Cough Syrap (Levosalbutamdl + Ambroxdl)"
    )
    assert numbered_lines[-1] == "[L044] Reg. No. TEST-0000"
    assert [line.split("] ", 1)[1] for line in numbered_lines] == source_lines


def test_prompt_explains_conservative_fragmented_column_association() -> None:
    source = DEVICE_OCR_PATH.read_text().rstrip("\n")
    prompt = build_prompt(ScanMode.PRESCRIPTION, source)

    assert "reading order may be fragmented across table columns" in prompt
    assert "complete one-to-one sequence" in prompt
    assert "same relative order as the medicine anchors" in prompt
    assert "build separate ordered lists" in prompt
    assert "do not attach every nearby modifier" in prompt
    assert "equal-length ordered layout is strong positional evidence" in prompt
    assert "A row without a written frequency leaves frequency null" in prompt
    assert "Parenthetical ingredient text" in prompt
    assert '"At night" and "at bedtime" are timing' in prompt
    assert "but not a numeric strength" in prompt
    assert "numeric strength ending in a lone `m`" in prompt
    assert "Do not copy diagnosis, complaints, general care advice" in prompt
    assert "conservative unambiguous OCR character normalization" in prompt
    assert "Every medicine object must include all schema keys" in prompt
    assert "use an empty list when none apply" in prompt
    assert "competing assignments are plausible" in prompt
    assert "leave the affected field null" in prompt
    assert source not in prompt
    assert "[L022] 1 tablet 3 times daily" in prompt


def test_layout_hints_group_candidates_without_changing_or_assigning_them() -> None:
    source = DEVICE_OCR_PATH.read_text().rstrip("\n")
    hints = build_layout_hints(source)

    assert hints.count("- candidate") == 19
    assert "MEDICINE_ANCHOR_ROWS:" in hints
    assert "candidate 1: [L009] 1. Paracetamol 500 mg" in hints
    assert "candidate 5: [L017] 5. Cough Syrap" in hints
    assert "DOSE_ROWS:" in hints
    assert "candidate 1: [L022] 1 tablet 3 times daily" in hints
    assert "candidate 5: [L035] 10 ml three times daly" in hints
    assert "FOOD_OR_TIMING_ROWS:" in hints
    assert "candidate 2: [L029] (after food)" in hints
    assert "candidate 3: [L030] at night" in hints
    assert "DURATION_ROWS:" in hints
    assert "candidate 2: [L037] 3 days" in hints
