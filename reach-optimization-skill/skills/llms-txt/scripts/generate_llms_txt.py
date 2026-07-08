#!/usr/bin/env python3
"""
generate_llms_txt.py — Generate or update an llms.txt file for any Git repository.

Implements the llms.txt spec (https://llmstxt.org/):
  - H1 with the project name (required)
  - Blockquote with a one-line summary
  - Optional prose with key facts (entity grounding for LLMs)
  - H2 sections containing `- [Title](url): description` link lists
  - An "Optional" section for resources that can be skipped in short contexts

Zero dependencies — Python 3.9+ stdlib only (TOML parsing uses tomllib on
3.11+ and degrades to regex below that).

Usage:
  python generate_llms_txt.py [--root PATH] [--dry-run] [--force] [--expand]
                              [--check] [--base-url URL] [--install-hook]
                              [--recommend] [--max-links N] [--quiet]

Exit codes: 0 = ok, 1 = error/refused, 2 = --check found drift.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import stat
import subprocess
import sys
from pathlib import Path, PurePosixPath

try:  # Python 3.11+
    import tomllib
except ImportError:  # pragma: no cover
    tomllib = None

# --------------------------------------------------------------------------
# Configuration
# --------------------------------------------------------------------------

GENERATED_MARKER = "<!-- generated-by: llms-txt-skill -->"

SKIP_DIRS = {
    ".git", ".hg", ".svn", "node_modules", "vendor", "dist", "build",
    "out", "target", "coverage", "__pycache__", ".venv", "venv", "env",
    ".tox", ".next", ".nuxt", ".cache", ".idea", ".vscode", "site",
    "htmlcov", ".pytest_cache", ".mypy_cache", ".ruff_cache",
}

DOC_EXTENSIONS = {".md", ".mdx", ".markdown"}

# Directories whose markdown content maps to an llms.txt section.
DIR_CATEGORIES = [
    (("docs", "doc", "documentation", "wiki", "guides"), "Documentation"),
    (("examples", "example", "demos", "demo", "samples", "tutorials", "cookbook"), "Examples"),
]

# Root-level filename stems (case-insensitive) mapped to sections.
ROOT_FILE_CATEGORIES = {
    "readme": "Documentation",
    "architecture": "Documentation",
    "api": "Documentation",
    "usage": "Documentation",
    "guide": "Documentation",
    "faq": "Documentation",
    "tutorial": "Documentation",
    "getting_started": "Documentation",
    "getting-started": "Documentation",
    "install": "Documentation",
    "installation": "Documentation",
    "contributing": "Development",
    "development": "Development",
    "developing": "Development",
    "hacking": "Development",
    "testing": "Development",
    "style": "Development",
    "code_of_conduct": "Optional",
    "code-of-conduct": "Optional",
    "changelog": "Optional",
    "changes": "Optional",
    "history": "Optional",
    "news": "Optional",
    "security": "Optional",
    "roadmap": "Optional",
    "license": "Optional",
    "licence": "Optional",
    "authors": "Optional",
    "support": "Optional",
}

SECTION_ORDER = ["Documentation", "Examples", "Development", "Optional"]

SUMMARY_MAX_LEN = 160

# Language detection: extension -> language, counted across the repo.
LANG_EXTENSIONS = {
    ".py": "Python", ".js": "JavaScript", ".jsx": "JavaScript",
    ".ts": "TypeScript", ".tsx": "TypeScript", ".rs": "Rust",
    ".go": "Go", ".rb": "Ruby", ".java": "Java", ".kt": "Kotlin",
    ".swift": "Swift", ".c": "C", ".h": "C", ".cpp": "C++",
    ".cc": "C++", ".cs": "C#", ".php": "PHP", ".ex": "Elixir",
    ".exs": "Elixir", ".sh": "Shell", ".lua": "Lua", ".zig": "Zig",
}


# --------------------------------------------------------------------------
# Small helpers
# --------------------------------------------------------------------------

def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def relpath_posix(path: Path, root: Path) -> str:
    return str(PurePosixPath(path.relative_to(root)))


def humanize(stem: str) -> str:
    """CONTRIBUTING -> Contributing, getting-started -> Getting Started."""
    words = re.split(r"[-_\s]+", stem.strip())
    return " ".join(w.capitalize() if not w.isupper() or len(w) > 4 else w.capitalize()
                    for w in words if w)


def strip_markdown_inline(text: str) -> str:
    """Reduce inline markdown to plain text for use in link descriptions."""
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text)          # images
    text = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)      # links -> text
    text = re.sub(r"`{1,3}([^`]*)`{1,3}", r"\1", text)        # code spans
    text = re.sub(r"[*_]{1,3}([^*_]+)[*_]{1,3}", r"\1", text) # emphasis
    text = re.sub(r"<[^>]+>", "", text)                       # raw html
    return re.sub(r"\s+", " ", text).strip()


def truncate_sentence(text: str, limit: int = SUMMARY_MAX_LEN) -> str:
    """Truncate at a sentence boundary near the limit, else at a word."""
    if len(text) <= limit:
        return text
    cut = text[:limit]
    for boundary in (". ", "; ", ", "):
        idx = cut.rfind(boundary)
        if idx > limit // 2:
            return cut[: idx + 1].rstrip(",;").rstrip()
    return cut.rsplit(" ", 1)[0].rstrip() + "…"


def is_badge_line(line: str) -> bool:
    """True for README lines that are only badges/images/links."""
    stripped = strip_markdown_inline(line)
    return bool(line.strip()) and not stripped


# --------------------------------------------------------------------------
# Markdown parsing
# --------------------------------------------------------------------------

def parse_markdown(text: str) -> dict:
    """Extract title (first H1), first prose paragraph, and all headings."""
    lines = text.splitlines()
    # Strip YAML frontmatter
    if lines and lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":
                lines = lines[i + 1:]
                break

    title = None
    headings = []  # (level, text)
    paragraph_lines: list[str] = []
    in_code = False

    for line in lines:
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        m = re.match(r"^(#{1,6})\s+(.*)", line)
        if m:
            level, text_h = len(m.group(1)), strip_markdown_inline(m.group(2))
            headings.append((level, text_h))
            if level == 1 and title is None:
                title = text_h
            if paragraph_lines:
                break  # we already have the first paragraph; headings past it
                       # aren't needed for summaries (full list rebuilt below)
            continue
        if paragraph_lines and not line.strip():
            break  # paragraph ended
        if title is not None or headings:
            stripped = line.strip()
            if (stripped and not is_badge_line(line)
                    and not stripped.startswith((">", "|", "-", "*", "+", "<"))
                    and not re.match(r"^\d+\.", stripped)):
                paragraph_lines.append(strip_markdown_inline(line))

    # Rebuild the complete heading list (the loop above may break early).
    all_headings = []
    in_code = False
    for line in lines:
        if line.lstrip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            continue
        m = re.match(r"^(#{1,6})\s+(.*)", line)
        if m:
            all_headings.append((len(m.group(1)), strip_markdown_inline(m.group(2))))

    # Prefer the README's own blockquote summary if one directly follows the H1.
    blockquote = None
    seen_title = False
    for line in lines:
        if re.match(r"^#\s+", line):
            seen_title = True
            continue
        if seen_title:
            stripped = line.strip()
            if not stripped or is_badge_line(line):
                continue
            if stripped.startswith(">"):
                blockquote = strip_markdown_inline(stripped.lstrip("> "))
            break

    return {
        "title": title,
        "summary": blockquote or " ".join(paragraph_lines).strip() or None,
        "headings": all_headings,
    }


def doc_entry(path: Path, root: Path, base_url: str) -> dict:
    """Build a link-list entry (title, url, description) for a markdown file."""
    parsed = parse_markdown(read_text(path))
    title = parsed["title"] or humanize(path.stem)
    summary = parsed["summary"]
    rel = relpath_posix(path, root)
    url = f"{base_url.rstrip('/')}/{rel}" if base_url else rel
    return {
        "title": title,
        "url": url,
        "path": rel,
        "description": truncate_sentence(summary) if summary else None,
        "depth": len(path.relative_to(root).parts),
    }


# --------------------------------------------------------------------------
# Repo metadata detection
# --------------------------------------------------------------------------

def load_toml(path: Path) -> dict:
    text = read_text(path)
    if not text:
        return {}
    if tomllib:
        try:
            return tomllib.loads(text)
        except Exception:
            return {}
    # Crude fallback for Python < 3.11: only top-level "key = "value"" pairs
    # inside [project] / [package] tables. Good enough for name/description.
    result, table = {}, None
    for line in text.splitlines():
        m = re.match(r"^\[([^\]]+)\]", line.strip())
        if m:
            table = m.group(1)
            result.setdefault(table, {})
            continue
        m = re.match(r'^(\w+)\s*=\s*"([^"]*)"', line.strip())
        if m and table:
            result[table][m.group(1)] = m.group(2)
    return result


def detect_git_remote_url(root: Path) -> str | None:
    """Return a browseable https URL for the origin remote, if any."""
    try:
        out = subprocess.run(
            ["git", "-C", str(root), "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=5,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if out.returncode != 0:
        return None
    url = out.stdout.strip()
    m = re.match(r"git@([^:]+):(.+?)(?:\.git)?$", url)
    if m:
        return f"https://{m.group(1)}/{m.group(2)}"
    if url.startswith("http"):
        return re.sub(r"\.git$", "", url)
    return None


# Scaffold-tool boilerplate that should never become the project summary.
PLACEHOLDER_DESCRIPTIONS = {
    "add your description here",
    "a short description of the project",
    "project description",
    "description",
    "todo",
    "",
}


def real_description(text) -> str | None:
    """Return the description unless it's known scaffolding boilerplate."""
    if not text or text.strip().lower() in PLACEHOLDER_DESCRIPTIONS:
        return None
    return text


def detect_metadata(root: Path) -> dict:
    """Project name + description from manifests, falling back to README."""
    name = description = None
    sources = []

    pkg = root / "package.json"
    if pkg.exists():
        try:
            data = json.loads(read_text(pkg))
            name = name or data.get("name")
            description = description or real_description(data.get("description"))
            sources.append("package.json")
        except json.JSONDecodeError:
            pass

    pyproject = root / "pyproject.toml"
    if pyproject.exists():
        data = load_toml(pyproject)
        project = data.get("project", {}) or data.get("tool", {}).get("poetry", {})
        name = name or project.get("name")
        description = description or real_description(project.get("description"))
        sources.append("pyproject.toml")

    cargo = root / "Cargo.toml"
    if cargo.exists():
        package = load_toml(cargo).get("package", {})
        name = name or package.get("name")
        description = description or real_description(package.get("description"))
        sources.append("Cargo.toml")

    composer = root / "composer.json"
    if composer.exists():
        try:
            data = json.loads(read_text(composer))
            name = name or data.get("name")
            description = description or real_description(data.get("description"))
            sources.append("composer.json")
        except json.JSONDecodeError:
            pass

    gomod = root / "go.mod"
    if gomod.exists():
        m = re.search(r"^module\s+(\S+)", read_text(gomod), re.MULTILINE)
        if m:
            name = name or m.group(1).rsplit("/", 1)[-1]
            sources.append("go.mod")

    readme = find_readme(root)
    readme_parsed = parse_markdown(read_text(readme)) if readme else {}
    name = name or readme_parsed.get("title") or root.resolve().name
    description = description or real_description(readme_parsed.get("summary"))
    if readme:
        sources.append(readme.name)

    return {
        "name": name,
        "description": truncate_sentence(description, 240) if description else None,
        "sources": sources,
        "readme": readme,
        "readme_headings": readme_parsed.get("headings", []),
        "remote_url": detect_git_remote_url(root),
    }


def find_readme(root: Path) -> Path | None:
    for candidate in ("README.md", "README.mdx", "README.markdown", "readme.md", "Readme.md"):
        p = root / candidate
        if p.exists():
            return p
    return None


def detect_primary_language(root: Path) -> str | None:
    counts: dict[str, int] = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")]
        for fn in filenames:
            lang = LANG_EXTENSIONS.get(Path(fn).suffix.lower())
            if lang:
                counts[lang] = counts.get(lang, 0) + 1
    return max(counts, key=counts.get) if counts else None


def detect_license_name(root: Path) -> str | None:
    for candidate in ("LICENSE", "LICENSE.md", "LICENSE.txt", "LICENCE", "COPYING"):
        p = root / candidate
        if p.exists():
            first_lines = read_text(p)[:400]
            for pattern, label in [
                (r"MIT License", "MIT"),
                (r"Apache License", "Apache-2.0"),
                (r"GNU GENERAL PUBLIC LICENSE", "GPL"),
                (r"BSD", "BSD"),
                (r"Mozilla Public License", "MPL-2.0"),
                (r"The Unlicense", "Unlicense"),
            ]:
                if re.search(pattern, first_lines, re.IGNORECASE):
                    return label
            return p.name
    return None


# --------------------------------------------------------------------------
# Document discovery
# --------------------------------------------------------------------------

def discover_docs(root: Path, base_url: str, max_links: int, log) -> dict:
    """Walk the repo and bucket markdown files into llms.txt sections."""
    sections: dict[str, list[dict]] = {s: [] for s in SECTION_ORDER}
    seen: set[str] = set()

    def add(category: str, path: Path):
        rel = relpath_posix(path, root)
        if rel in seen:
            return
        seen.add(rel)
        sections[category].append(doc_entry(path, root, base_url))

    # 1. Root-level files first — they're the highest-signal entry points.
    for child in sorted(root.iterdir()):
        if not child.is_file():
            continue
        stem = re.sub(r"\.(md|mdx|markdown|txt|rst)$", "", child.name, flags=re.IGNORECASE)
        category = ROOT_FILE_CATEGORIES.get(stem.lower())
        if category is None:
            continue
        if child.suffix.lower() in DOC_EXTENSIONS or stem.lower() in ("license", "licence"):
            add(category, child)

    # 2. Categorized directories (docs/, examples/, ...), top-down.
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(
            d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")
        )
        current = Path(dirpath)
        if current == root:
            continue
        top = current.relative_to(root).parts[0].lower()
        category = next(
            (cat for names, cat in DIR_CATEGORIES if top in names), None
        )
        if category is None:
            # .github docs (e.g. CONTRIBUTING under .github) are picked up here
            if top == ".github":
                category = "Development"
            else:
                continue
        for fn in sorted(filenames):
            p = current / fn
            if p.suffix.lower() in DOC_EXTENSIONS:
                add(category, p)

    # Sort each section: shallow files first, then alphabetically; cap size.
    for cat, entries in sections.items():
        entries.sort(key=lambda e: (e["depth"], e["path"].lower()))
        if len(entries) > max_links:
            dropped = len(entries) - max_links
            sections[cat] = entries[:max_links]
            log(f"note: section '{cat}' capped at {max_links} links "
                f"({dropped} dropped — raise with --max-links)")

    return sections


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------

def render_llms_txt(meta: dict, sections: dict, root: Path) -> str:
    lines = [f"# {meta['name']}", ""]
    if meta["description"]:
        lines += [f"> {meta['description']}", ""]

    # Short prose block: key facts that ground the project as an entity.
    facts = []
    if meta.get("language"):
        facts.append(f"primarily written in {meta['language']}")
    if meta.get("license"):
        facts.append(f"licensed under {meta['license']}")
    if meta.get("remote_url"):
        facts.append(f"hosted at {meta['remote_url']}")
    if facts:
        lines += [f"{meta['name']} is {', '.join(facts)}.", ""]

    for section in SECTION_ORDER:
        entries = sections.get(section) or []
        if not entries:
            continue
        lines.append(f"## {section}")
        lines.append("")
        for e in entries:
            desc = f": {e['description']}" if e["description"] else ""
            lines.append(f"- [{e['title']}]({e['url']}){desc}")
        lines.append("")

    lines.append(GENERATED_MARKER)
    return "\n".join(lines) + "\n"


def render_context_file(meta: dict, sections: dict, root: Path,
                        include_optional: bool) -> str:
    """Inline the linked docs into one context file (llms-ctx / llms-full).

    Mirrors the output shape of the official llms_txt2ctx tool: a <project>
    wrapper with one <doc> element per linked file.
    """
    parts = [f'<project title="{meta["name"]}" '
             f'summary="{(meta["description"] or "").replace(chr(34), chr(39))}">']
    for section in SECTION_ORDER:
        if section == "Optional" and not include_optional:
            continue
        for e in sections.get(section) or []:
            path = root / e["path"]
            content = read_text(path).strip()
            if not content:
                continue
            parts.append(f'<doc title="{e["title"]}" path="{e["path"]}">')
            parts.append(content)
            parts.append("</doc>")
    parts.append("</project>")
    return "\n\n".join(parts) + "\n"


# --------------------------------------------------------------------------
# AIO recommendations (--recommend)
# --------------------------------------------------------------------------

def aio_recommendations(meta: dict, sections: dict, root: Path) -> str:
    """Heuristic audit: how AI-discoverable is this repo, and what to fix."""
    checks = []

    def check(ok: bool, label: str, fix: str):
        checks.append(("PASS" if ok else "FIX ", label if ok else f"{label} — {fix}"))

    readme = meta.get("readme")
    headings = meta.get("readme_headings", [])
    heading_texts = [h[1].lower() for h in headings]

    check(readme is not None, "README.md exists",
          "add a README.md — it is the #1 source LLMs read and cite")
    check(bool(meta["description"]), "Answer-first summary detected",
          "open the README with a 1–2 sentence plain-language statement of "
          "what the project is and who it's for, before any badges or ToC")
    check(any("install" in h for h in heading_texts), "Installation section",
          "add an '## Installation' heading with copy-pasteable commands")
    check(any(h in heading_texts for h in ("usage", "quick start", "quickstart", "getting started")),
          "Usage / Quick start section",
          "add a '## Usage' or '## Quick start' section with a minimal working example")
    check(any("faq" in h for h in heading_texts), "FAQ section",
          "add an '## FAQ' with literal questions as H3 headings — answer "
          "engines match user queries against question-phrased headings")
    check(bool(sections.get("Examples")), "Examples discovered",
          "add an examples/ directory with self-contained, runnable examples")
    check((root / "llms.txt").exists(), "llms.txt present",
          "run this tool without --recommend to generate it")
    check(any(h[0] == 2 for h in headings) if headings else False,
          "README uses H2 section structure",
          "structure the README with ## headings so retrievers can chunk it cleanly")

    out = ["AIO / AEO audit", "================", ""]
    for status, line in checks:
        out.append(f"[{status}] {line}")
    out += [
        "",
        "General guidance for AI-retrievable docs:",
        "  1. Answer-first: every page opens with the answer, then the detail.",
        "  2. One concept per H2 section; phrase FAQ headings as literal questions.",
        "  3. Define entities on first use ('Foo, a Python CLI for X') — models",
        "     cite text that disambiguates the project from similarly-named ones.",
        "  4. Prefer plain markdown over HTML in docs; keep tables small.",
        "  5. Keep canonical facts (version, license, requirements) in one place",
        "     and link to it, rather than repeating them — drift causes miscitation.",
        "  6. Regenerate llms.txt when docs change (see --install-hook).",
    ]
    return "\n".join(out)


# --------------------------------------------------------------------------
# Git hook installation (--install-hook)
# --------------------------------------------------------------------------

HOOK_BEGIN = "# >>> llms-txt-skill hook >>>"
HOOK_END = "# <<< llms-txt-skill hook <<<"


def install_hook(root: Path, log) -> int:
    git_dir = root / ".git"
    if not git_dir.is_dir():
        log("error: not a git repository (no .git directory)")
        return 1
    hooks_dir = git_dir / "hooks"
    hooks_dir.mkdir(exist_ok=True)
    hook_path = hooks_dir / "pre-commit"
    script_path = Path(__file__).resolve()

    block = "\n".join([
        HOOK_BEGIN,
        "# Regenerate llms.txt when docs change, and stage the result.",
        'if git diff --cached --name-only | grep -qiE "\\.(md|mdx|markdown)$|^(package\\.json|pyproject\\.toml|Cargo\\.toml)$"; then',
        f'  python3 "{script_path}" --root "$(git rev-parse --show-toplevel)" --force --quiet || exit 1',
        "  git add llms.txt 2>/dev/null || true",
        "fi",
        HOOK_END,
    ])

    if hook_path.exists():
        content = read_text(hook_path)
        if HOOK_BEGIN in content:
            # Replace the existing managed block in place.
            content = re.sub(
                re.escape(HOOK_BEGIN) + r".*?" + re.escape(HOOK_END),
                block, content, flags=re.DOTALL,
            )
        else:
            content = content.rstrip("\n") + "\n\n" + block + "\n"
    else:
        content = "#!/bin/sh\n\n" + block + "\n"

    hook_path.write_text(content, encoding="utf-8")
    hook_path.chmod(hook_path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    log(f"installed pre-commit hook: {hook_path}")
    return 0


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Generate an llms.txt (https://llmstxt.org/) for this repository."
    )
    parser.add_argument("--root", default=".", help="repository root (default: cwd)")
    parser.add_argument("--output", default="llms.txt", help="output filename")
    parser.add_argument("--base-url", default="",
                        help="absolute URL prefix for links (e.g. the raw GitHub URL); "
                             "default is repo-relative paths")
    parser.add_argument("--force", action="store_true",
                        help="overwrite an existing llms.txt that this tool did not generate")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the generated file to stdout; write nothing")
    parser.add_argument("--expand", action="store_true",
                        help="also generate llms-ctx.txt (linked docs inlined, Optional "
                             "excluded) and llms-full.txt (everything inlined)")
    parser.add_argument("--check", action="store_true",
                        help="exit 2 if llms.txt is missing or out of date (for CI)")
    parser.add_argument("--install-hook", action="store_true",
                        help="install a git pre-commit hook that keeps llms.txt fresh")
    parser.add_argument("--recommend", action="store_true",
                        help="print an AIO/AEO audit of the repo with fixes; writes nothing")
    parser.add_argument("--max-links", type=int, default=20,
                        help="max links per section (default 20)")
    parser.add_argument("--quiet", action="store_true", help="suppress progress output")
    args = parser.parse_args(argv)

    def log(msg: str):
        if not args.quiet:
            print(msg, file=sys.stderr)

    root = Path(args.root).resolve()
    if not root.is_dir():
        log(f"error: {root} is not a directory")
        return 1

    if args.install_hook:
        return install_hook(root, log)

    log(f"analyzing {root} ...")
    meta = detect_metadata(root)
    meta["language"] = detect_primary_language(root)
    meta["license"] = detect_license_name(root)
    sections = discover_docs(root, args.base_url, args.max_links, log)
    log(f"project: {meta['name']!r} (sources: {', '.join(meta['sources']) or 'directory name'})")

    if args.recommend:
        print(aio_recommendations(meta, sections, root))
        return 0

    rendered = render_llms_txt(meta, sections, root)
    output_path = root / args.output

    if args.dry_run:
        print(rendered, end="")
        if args.expand:
            log("--dry-run: skipping context-file expansion output")
        return 0

    if args.check:
        existing = read_text(output_path)
        if existing == rendered:
            log("llms.txt is up to date")
            return 0
        log("llms.txt is missing or out of date — regenerate with: "
            "python generate_llms_txt.py --force")
        return 2

    if output_path.exists():
        existing = read_text(output_path)
        if GENERATED_MARKER not in existing and not args.force:
            log(f"refusing to overwrite {output_path}: it was not generated by this "
                f"tool (no marker found). Re-run with --force to overwrite.")
            return 1

    output_path.write_text(rendered, encoding="utf-8")
    log(f"wrote {output_path}")

    if args.expand:
        ctx = render_context_file(meta, sections, root, include_optional=False)
        full = render_context_file(meta, sections, root, include_optional=True)
        (root / "llms-ctx.txt").write_text(ctx, encoding="utf-8")
        (root / "llms-full.txt").write_text(full, encoding="utf-8")
        log(f"wrote {root / 'llms-ctx.txt'} and {root / 'llms-full.txt'}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
