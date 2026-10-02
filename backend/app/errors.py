class ProviderServiceError(Exception):
    def __init__(
        self,
        code: str,
        message: str,
        *,
        retryable: bool,
        status_code: int,
        retry_after: str | None = None,
    ):
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable
        self.status_code = status_code
        self.retry_after = retry_after


class InvalidModelOutputError(ProviderServiceError):
    def __init__(self) -> None:
        super().__init__(
            "invalid_model_output",
            "We could not reliably read this prescription. Please retry or rescan.",
            retryable=True,
            status_code=502,
        )


class NoMedicineDetectedError(ProviderServiceError):
    def __init__(self) -> None:
        super().__init__(
            "no_medicine_detected",
            "No medicine could be confidently detected. Please retry or rescan.",
            retryable=True,
            status_code=502,
        )
