import pytest


@pytest.mark.skip(
    reason=(
        "Deferred manual verification: requires an explicitly supplied "
        "GEMINI_API_KEY and must never run in the default test suite."
    )
)
def test_live_gemini_extraction_is_deferred() -> None:
    """Document the intentionally deferred live-provider acceptance test."""
