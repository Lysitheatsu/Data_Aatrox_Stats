"""
logging.py

Structured JSON logger configuration.
"""

import logging
import sys


def setup_logging() -> logging.Logger:
    logger = logging.getLogger("elly_backend")
    logger.setLevel(logging.INFO)

    if not logger.handlers:
        formatter = logging.Formatter(
            fmt="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )

        # Console Handler
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setFormatter(formatter)
        logger.addHandler(console_handler)

        # File Handler
        try:
            import os
            log_dir = os.path.join(
                os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
                "logs"
            )
            os.makedirs(log_dir, exist_ok=True)
            log_file_path = os.path.join(log_dir, "elly_backend.log")
            file_handler = logging.FileHandler(
                log_file_path,
                encoding="utf-8"
            )
            file_handler.setFormatter(formatter)
            logger.addHandler(file_handler)
        except Exception as e:
            sys.stderr.write(f"Could not setup log file handler: {e}\n")

    return logger


logger = setup_logging()