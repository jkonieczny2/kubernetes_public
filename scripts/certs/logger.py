import logging

LOG_LEVELS = {
    'DEBUG': logging.DEBUG,
    'INFO': logging.INFO,
    'WARNING': logging.WARNING,
    'ERROR': logging.ERROR,
    'CRITICAL': logging.CRITICAL,
}

DEFAULT_FORMAT = "%(asctime)s %(levelname)s %(name)s - %(message)s"

def setup_logging(log_level, fmt=DEFAULT_FORMAT, handlers=None):
    """
    Setup logging.basicConfig for logging to console
    """
    lvl = LOG_LEVELS[log_level]

    handlers = [logging.StreamHandler()] if handlers is None else handlers

    logging.basicConfig(
        level = lvl,
        format=fmt,
        handlers=handlers,
    )
