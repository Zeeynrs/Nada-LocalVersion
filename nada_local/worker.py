"""Run blocking work (file indexing, metadata, LRCLIB) off the UI thread."""

import traceback
from concurrent.futures import ThreadPoolExecutor

from PySide6.QtCore import QObject, Signal, Slot


class Async(QObject):
    _done = Signal(object, object, object)
    error = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._pool = ThreadPoolExecutor(max_workers=4, thread_name_prefix="nada-local")
        self._done.connect(self._dispatch)

    def run(self, fn, on_ok=None, on_err=None):
        def job():
            try:
                result = fn()
            except Exception as e:
                traceback.print_exc()
                self._done.emit(on_err or self._default_err, None, e)
            else:
                if on_ok:
                    self._done.emit(on_ok, result, None)
        self._pool.submit(job)

    def _default_err(self, e):
        self.error.emit(str(e))

    @Slot(object, object, object)
    def _dispatch(self, callback, result, err):
        callback(err if err is not None else result)

    def shutdown(self):
        self._pool.shutdown(wait=False, cancel_futures=True)
