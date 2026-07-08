# SKILLS

Source-of-truth repository for custom Claude Code skills. The actual skill
content lives here (version-controlled), and Claude Code loads each skill via a
**symlink** placed in `~/.claude/skills/`.

## How it works

Claude Code discovers skills by scanning `~/.claude/skills/`. Rather than copying
skills into that directory, each skill is symlinked back to its real location in
this repo. This means:

- There is **one** copy of each skill (here), tracked in git.
- Editing a file here immediately affects the skill Claude Code uses — no re-sync.
- `~/.claude/skills/<name>` is just a pointer, not a duplicate.

Note that skills are nested one level deep inside each `*-skill` project, under a
`skills/` subdirectory. The symlink hides that nesting so the skill appears at the
top level of `~/.claude/skills/`.

## Current symlinks

Each entry below is `~/.claude/skills/<name>` → target in this repo:

| Skill name           | Target |
| -------------------- | ------ |
| `fable-prompts`      | `SKILLS/fable-prompts-skill/skills/fable-prompts` |
| `intelligent-loop`   | `SKILLS/fable-prompts-skill/skills/intelligent-loop` |
| `repo-conventions`   | `SKILLS/fable-prompts-skill/skills/repo-conventions` |
| `llms-txt`           | `SKILLS/reach-optimization-skill/skills/llms-txt` |
| `reach-optimization` | `SKILLS/reach-optimization-skill/skills/reach-optimization` |

## How to create a new symlink

To expose a skill in this repo to Claude Code:

```bash
ln -s /home/telep/Projects/SKILLS/<project>-skill/skills/<name> \
      ~/.claude/skills/<name>
```

Example (this is exactly how `intelligent-loop` is wired up):

```bash
ln -s /home/telep/Projects/SKILLS/fable-prompts-skill/skills/intelligent-loop \
      ~/.claude/skills/intelligent-loop
```

## How to verify

1. **Confirm the symlink exists and points into this repo:**

   ```bash
   ls -la ~/.claude/skills/intelligent-loop
   ```

   Expected: an `l` at the start of the permissions and an arrow pointing to
   `/home/telep/Projects/SKILLS/fable-prompts-skill/skills/intelligent-loop`.

2. **Confirm the target resolves to a real directory with skill content:**

   ```bash
   readlink -f ~/.claude/skills/intelligent-loop
   ls ~/.claude/skills/intelligent-loop/   # should show SKILL.md (and README.md)
   ```

3. **Check for broken symlinks** (targets that no longer exist):

   ```bash
   find ~/.claude/skills/ -maxdepth 1 -xtype l
   ```

   Any path printed here is a **dangling** symlink and needs fixing.

4. **Confirm Claude Code sees it:** the skill should be invocable as
   `/intelligent-loop` inside Claude Code.

## Verify all SKILLS-backed symlinks at once

```bash
for l in ~/.claude/skills/*; do
  [ -L "$l" ] || continue
  tgt=$(readlink "$l")
  case "$tgt" in
    */Projects/SKILLS/*)
      if [ -e "$l" ]; then status="OK"; else status="BROKEN"; fi
      printf '%-22s %-7s -> %s\n' "$(basename "$l")" "$status" "$tgt";;
  esac
done
```
