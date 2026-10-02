import pytest


@pytest.mark.skip(
    reason=(
        "Manual acceptance only: requires an explicitly supplied GROQ_API_KEY "
        "and must never run in the default test suite."
    )
)
def test_live_groq_extraction_is_manual_only() -> None:
    """Document the intentionally manual live-provider acceptance test."""
