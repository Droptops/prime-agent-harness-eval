"""Ground truth for task 7 — transitive import closure.

Chosen because every prior task saturated at 100% for both conditions: they were
mechanical aggregations, and a competent agent with a code interpreter just does
them. This one is still exactly checkable but has real depth:

  - it is a graph reachability problem, not a per-file tally
  - TS ESM imports here are written with .js extensions that resolve to .ts
  - directory imports resolve via index.ts
  - cycles exist and must not hang the traversal
  - a plausible shortcut (direct importers only) gives a clearly wrong answer

Computed on the HOST so the key never enters the container.
"""
import json
import re
import sys
from pathlib import Path

# resolve() everywhere: paths from rglob are absolute, so a relative REPO makes
# every startswith()/relative_to() comparison silently fail.
REPO = Path(sys.argv[1] if len(sys.argv) > 1 else "./pa").resolve()
OUT = Path(sys.argv[2] if len(sys.argv) > 2 else "./truth-task7.json")

SRC = (REPO / "packages" / "coding-agent" / "src").resolve()
TARGET = (REPO / "packages" / "ai" / "src" / "types.ts").resolve()

# Match every `from "..."` specifier. An earlier version anchored on
# ^import/^export with [^;\n]*?, which cannot cross a newline and therefore
# missed every MULTI-LINE import -- ubiquitous in this codebase, and the reason
# an earlier key undercounted the closure by 6. In a .ts file any `from "X"`
# is an import/export specifier, so matching it directly is both simpler and
# correct.
IMPORT_RE = re.compile(r'\bfrom\s*["\']([^"\']+)["\']')
BARE_IMPORT_RE = re.compile(r'^\s*import\s+["\']([^"\']+)["\']', re.M)

files = [p.resolve() for p in SRC.rglob("*.ts") if p.is_file()]


# Workspace package name -> source dir. Package names do NOT match directory
# names here (packages/ai is "@earendil-works/pi-ai"), so build the map from
# each package.json rather than guessing.
PKG_SRC = {}
for pj in (REPO / "packages").glob("*/package.json"):
    m = re.search(r'"name"\s*:\s*"([^"]+)"', pj.read_text(encoding="utf-8"))
    if m:
        PKG_SRC[m.group(1)] = pj.parent / "src"


def resolve(spec: str, importer: Path):
    """Resolve an import specifier to a file on disk, or None."""
    if spec.startswith("."):
        base = (importer.parent / spec).resolve()
    else:
        # exact workspace package, or a subpath export like pkg/oauth
        for name, srcdir in PKG_SRC.items():
            if spec == name:
                base = (srcdir / "index.ts").resolve()
                return base if base.exists() else None
            if spec.startswith(name + "/"):
                sub = spec[len(name) + 1:]
                for c in (srcdir / f"{sub}.ts", srcdir / sub / "index.ts",
                          srcdir / "providers" / f"{sub}.ts"):
                    if c.exists():
                        return c.resolve()
                return None
        return None
    cands = []
    if base.suffix == ".js":
        cands.append(base.with_suffix(".ts"))
    cands += [base, base.with_suffix(".ts"),
              Path(str(base) + ".ts"), base / "index.ts"]
    for c in cands:
        if c.exists() and c.is_file() and c.suffix == ".ts":
            return c.resolve()
    return None


# adjacency: file -> set of files it imports
edges = {}
for f in files:
    txt = f.read_text(encoding="utf-8", errors="replace")
    specs = set(IMPORT_RE.findall(txt)) | set(BARE_IMPORT_RE.findall(txt))
    out = set()
    for s in specs:
        r = resolve(s, f)
        if r:
            out.add(r)
    edges[f] = out

# Resolve imports for EVERY package's sources, not just ai/. Restricting the
# graph to coding-agent + ai silently drops paths that route through another
# workspace package: cli/args.ts imports @earendil-works/pi-agent-core, and
# packages/agent/src reaches pi-ai -> types.ts. That omission undercounted the
# closure by 6.
for pkg_src in PKG_SRC.values():
    for f in (p.resolve() for p in pkg_src.rglob("*.ts")):
        if f in edges:
            continue
        txt = f.read_text(encoding="utf-8", errors="replace")
        specs = set(IMPORT_RE.findall(txt)) | set(BARE_IMPORT_RE.findall(txt))
        edges[f] = {r for r in (resolve(s, f) for s in specs) if r}

# reverse reachability from TARGET, iterated to fixpoint (handles cycles)
reaches = set()
changed = True
while changed:
    changed = False
    for f, outs in edges.items():
        if f in reaches:
            continue
        if TARGET in outs or (outs & reaches):
            reaches.add(f)
            changed = True

coding_hits = sorted(
    str(p.relative_to(REPO).as_posix()) for p in reaches
    if str(p).startswith(str(SRC))
)
direct = sorted(
    str(p.relative_to(REPO).as_posix()) for p in files
    if TARGET in edges.get(p, ())
)

truth = {
    "transitive_importer_count": len(coding_hits),
    "direct_importer_count": len(direct),
    "first_ten_transitive": coding_hits[:10],
    "total_ts_files_scanned": len(files),
}
OUT.write_text(json.dumps(truth, indent=2, sort_keys=True), encoding="utf-8")
print(json.dumps(truth, indent=2, sort_keys=True))
print(f"\n[sanity] transitive={len(coding_hits)} direct={len(direct)} "
      f"scanned={len(files)}  (transitive must exceed direct for this to be a real test)")
