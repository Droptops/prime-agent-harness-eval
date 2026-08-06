"""Ground truth for task 6 (parallel per-package aggregation).

Computed on the HOST so the answer key never exists inside the container --
the contamination control that task 5 needed retrofitted.

Definitions are pinned to exactly what the prompt asks for:
  ts_files            .ts files anywhere under packages/<pkg>/src
  total_lines         sum of line counts of those files
  largest_file        by line count; ties broken by alphabetically-last path
  exported_functions  lines matching ^export (async )?function
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(sys.argv[1] if len(sys.argv) > 1 else "./pa")
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else "./truth-task6.json")
PKGS = ["agent", "ai", "coding-agent", "tui"]

EXPORT_FN = re.compile(r"^export (?:async )?function\b", re.M)

truth = {}
for pkg in PKGS:
    root = REPO / "packages" / pkg / "src"
    files = sorted(p for p in root.rglob("*.ts") if p.is_file())
    total = 0
    best = None  # (lines, path)
    exported = 0
    for f in files:
        txt = f.read_text(encoding="utf-8", errors="replace")
        n = len(txt.splitlines())
        total += n
        rel = f.relative_to(REPO).as_posix()
        if best is None or (n, rel) > best:
            best = (n, rel)
        exported += len(EXPORT_FN.findall(txt))
    truth[pkg] = {
        "ts_files": len(files),
        "total_lines": total,
        "largest_file": {"path": best[1], "lines": best[0]},
        "exported_functions": exported,
    }

OUT.write_text(json.dumps(truth, indent=2, sort_keys=True), encoding="utf-8")
print(json.dumps(truth, indent=2, sort_keys=True))
