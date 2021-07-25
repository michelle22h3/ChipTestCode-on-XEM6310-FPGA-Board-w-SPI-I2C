"""
This module implements the customized logging formatter.
"""

import logging


class CustomFormatter(logging.Formatter):
    """Logging Formatter to add colors and count warning / errors."""

    # Color platte: https://www.lihaoyi.com/post/BuildyourownCommandLinewithANSIescapecodes.html
    GREY = "\x1b[38;21m"
    YELLOW = "\x1b[33;21m"
    BLUE = "\x1b[34m"
    RED = "\x1b[31;21m"
    BOLD_RED = "\x1b[31;1m"
    RESET = "\x1b[0m"
    FORMAT = "%(asctime)s - %(name)s - %(levelname)s - %(message)s (%(filename)s:%(lineno)d)"

    FORMATS = {
        logging.DEBUG: GREY + FORMAT + RESET,
        logging.INFO: BLUE + FORMAT + RESET,
        logging.WARNING: YELLOW + FORMAT + RESET,
        logging.ERROR: RED + FORMAT + RESET,
        logging.CRITICAL: BOLD_RED + FORMAT + RESET,
    }

    def format(self, record):
        log_format = self.FORMATS[record.levelno]
        formatter = logging.Formatter(log_format)
        return formatter.format(record)


def setup_logger(log_name, log_level):
    """Helper to setup logger with the specified name and verbose logging level."""
    logger = logging.getLogger(log_name)
    logger.setLevel(log_level)
    handler = logging.StreamHandler()
    handler.setFormatter(CustomFormatter())
    logger.addHandler(handler)
