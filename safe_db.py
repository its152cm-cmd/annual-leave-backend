"""Retries a database READ that failed because of a short network hiccup
(for example Windows "WinError 10035" when several requests run at once)."""
import time

import httpx

TRANSIENT = (httpx.TransportError,)
RETRY_METHODS = {"GET", "HEAD", "DELETE"}  # safe to send twice; inserts/updates are never repeated


class SafeBuilder:
    def __init__(self, inner):
        self._inner = inner

    def __getattr__(self, name):
        attr = getattr(self._inner, name)
        if not callable(attr):
            return attr

        def call(*args, **kwargs):
            result = attr(*args, **kwargs)
            return SafeBuilder(result) if hasattr(result, "execute") else result

        return call

    def execute(self, *args, **kwargs):
        method = str(getattr(getattr(self._inner, "request", None), "http_method", "") or "").upper()
        tries = 3 if method in RETRY_METHODS else 1
        for attempt in range(tries):
            try:
                return self._inner.execute(*args, **kwargs)
            except TRANSIENT as e:
                if attempt == tries - 1:
                    raise
                print(f"[db] network hiccup ({type(e).__name__}); trying again")
                time.sleep(0.25 * (attempt + 1))


class SafeClient:
    def __init__(self, inner):
        self._inner = inner

    def __getattr__(self, name):
        attr = getattr(self._inner, name)
        if name in ("table", "from_", "rpc") and callable(attr):
            def call(*args, **kwargs):
                result = attr(*args, **kwargs)
                return SafeBuilder(result) if hasattr(result, "execute") else result
            return call
        return attr
