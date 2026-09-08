# Symlink skills in this repo for Claude Code, Codex, and Cursor.
# Only symlinks that point INTO this repo are ever created, replaced, or removed —
# links owned by other repos (second-brain, omarchy, …) are never touched.

REPO_DIR    := $(CURDIR)
AGENT       ?= claude
AGENTS      := claude codex cursor
claude_DIR  := $(HOME)/.claude/skills
codex_DIR   := $(HOME)/.agents/skills
cursor_DIR  := $(HOME)/.cursor/skills
ifeq ($(filter $(AGENT),$(AGENTS)),)
$(error Unknown AGENT '$(AGENT)'; choose claude, codex, or cursor)
endif
TARGET_DIR  ?= $($(AGENT)_DIR)
SKILL_DIRS  := $(shell find $(REPO_DIR) -name SKILL.md -not -path '*/.git/*' -exec dirname {} \; | sort)

.DEFAULT_GOAL := help
ACTIONS := link unlink relink status check
AGENT_TARGETS := $(foreach agent,$(AGENTS),$(addsuffix -$(agent),$(ACTIONS)))
.PHONY: help $(ACTIONS) $(AGENT_TARGETS)

$(AGENT_TARGETS):
	@$(MAKE) --no-print-directory $(word 1,$(subst -, ,$@)) AGENT=$(word 2,$(subst -, ,$@))

help: ## Show this help
	@echo "Skills repo — symlink management for $(AGENT): $(TARGET_DIR)"
	@echo
	@echo "Usage: make <target> [AGENT=claude|codex|cursor]"
	@echo
	@grep -E '^[a-z]+: ##' $(MAKEFILE_LIST) | awk -F': ## ' '{printf "  \033[1m%-8s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Shortcuts: make link-codex, link-cursor (also unlink, relink, status, check)"
	@echo "Override destination: make link AGENT=codex TARGET_DIR=/path/to/skills"
	@echo
	@echo "Skills in this repo: $(words $(SKILL_DIRS))"

link: ## Symlink every skill in this repo into the selected agent skills directory (idempotent)
	@mkdir -p "$(TARGET_DIR)"
	@set -e; for dir in $(SKILL_DIRS); do \
	  name=$$(basename $$dir); \
	  target="$(TARGET_DIR)/$$name"; \
	  if [ -L "$$target" ]; then \
	    case "$$(readlink "$$target")" in \
	      $(REPO_DIR)/*) \
	        if [ "$$(readlink "$$target")" = "$$dir" ]; then \
	          echo "  ok      $$name"; \
	        else \
	          ln -sfn "$$dir" "$$target"; echo "  updated $$name -> $$dir"; \
	        fi ;; \
	      *) echo "  SKIP    $$name (symlink owned by another repo: $$(readlink "$$target"))" ;; \
	    esac; \
	  elif [ -e "$$target" ]; then \
	    echo "  SKIP    $$name (a real file/directory exists there)"; \
	  else \
	    ln -s "$$dir" "$$target"; echo "  linked  $$name -> $$dir"; \
	  fi; \
	done

unlink: ## Remove only the symlinks that point into this repo
	@set -e; for l in "$(TARGET_DIR)"/*; do \
	  [ -L "$$l" ] || continue; \
	  case "$$(readlink "$$l")" in \
	    $(REPO_DIR)/*) rm "$$l"; echo "  removed $$(basename $$l)" ;; \
	  esac; \
	done

relink: ## unlink then link (clears stale links from renamed/deleted skills)
	@$(MAKE) --no-print-directory unlink
	@$(MAKE) --no-print-directory link

status: ## Show every symlink in the selected agent skills directory and where it points
	@set -e; for l in "$(TARGET_DIR)"/*; do \
	  [ -L "$$l" ] || continue; \
	  tgt=$$(readlink "$$l"); \
	  if [ -e "$$l" ]; then st=OK; else st=BROKEN; fi; \
	  case "$$tgt" in $(REPO_DIR)/*) owner="this repo";; *) owner="other";; esac; \
	  printf "  %-26s %-7s %-10s -> %s\n" "$$(basename $$l)" "$$st" "($$owner)" "$$tgt"; \
	done

check: ## Fail if any skill in this repo is unlinked, or any repo-owned link is broken
	@fail=0; \
	for dir in $(SKILL_DIRS); do \
	  name=$$(basename $$dir); \
	  target="$(TARGET_DIR)/$$name"; \
	  if [ ! -L "$$target" ]; then echo "  MISSING $$name (run 'make link')"; fail=1; \
	  elif [ ! -e "$$target" ]; then echo "  BROKEN  $$name -> $$(readlink "$$target")"; fail=1; \
	  elif [ "$$(readlink -f "$$target")" != "$$(readlink -f "$$dir")" ]; then echo "  CONFLICT $$name -> $$(readlink "$$target")"; fail=1; \
	  fi; \
	done; \
	for l in "$(TARGET_DIR)"/*; do \
	  [ -L "$$l" ] && [ ! -e "$$l" ] || continue; \
	  case "$$(readlink "$$l")" in \
	    $(REPO_DIR)/*) echo "  STALE   $$(basename $$l) -> $$(readlink "$$l") (run 'make relink')"; fail=1 ;; \
	  esac; \
	done; \
	[ $$fail -eq 0 ] && echo "  all $(words $(SKILL_DIRS)) skills linked and healthy" || exit 1
