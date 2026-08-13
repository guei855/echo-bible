"""Deprecated entry point that delegates to the safe production builder."""

import runpy
from pathlib import Path


BUILDER = Path(__file__).resolve().parents[1] / "bible_builder" / "build_strong_db.py"

runpy.run_path(str(BUILDER), run_name="__main__")
