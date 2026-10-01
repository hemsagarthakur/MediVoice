class GeminiServiceError(Exception):
    def __init__(self, code: str, message: str, *, retryable: bool, status_code: int):
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable
        self.status_code = status_code


class InvalidModelOutputError(GeminiServiceError):
    def __init__(self) -> None:
        super().__init__(
            "invalid_model_output",
            "We could not reliably read this prescription. Please retry or rescan.",
            retryable=True,
            status_code=502,
        )

