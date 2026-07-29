# Symlink skills in this repo into ~/.claude/skills so Claude Code can load them.
# Only symlinks that point INTO this repo are ever created, replaced, or removed —
# links owned by other repos (second-brain, omarchy, …) are never touched.

REPO_DIR    := $(CURDIR)
TARGET_DIR  := $(HOME)/.claude/skills
SKILL_DIRS  := $(shell find $(REPO_DIR) -name SKILL.md -not -path '*/.git/*' -exec dirname {} \; | sort)

.DEFAULT_GOAL := help
.PHONY: help link unlink relink status check

help: ## Show this help
	@echo "Skills repo — symlink management for ~/.claude/skills"
	@echo
	@echo "Usage: make <target>"
	@echo
	@grep -E '^[a-z]+: ##' $(MAKEFILE_LIST) | awk -F': ## ' '{printf "  \033[1m%-8s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Skills in this repo: $(words $(SKILL_DIRS))"

link: ## Symlink every skill in this repo into ~/.claude/skills (idempotent)
	@mkdir -p $(TARGET_DIR)
	@for dir in $(SKILL_DIRS); do \
	  name=$$(basename $$dir); \
	  target=$(TARGET_DIR)/$$name; \
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
	@for l in $(TARGET_DIR)/*; do \
	  [ -L "$$l" ] || continue; \
	  case "$$(readlink "$$l")" in \
	    $(REPO_DIR)/*) rm "$$l"; echo "  removed $$(basename $$l)" ;; \
	  esac; \
	done

relink: ## unlink then link (clears stale links from renamed/deleted skills)
	@$(MAKE) --no-print-directory unlink
	@$(MAKE) --no-print-directory link

status: ## Show every symlink in ~/.claude/skills and where it points
	@for l in $(TARGET_DIR)/*; do \
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
	  target=$(TARGET_DIR)/$$name; \
	  if [ ! -L "$$target" ]; then echo "  MISSING $$name (run 'make link')"; fail=1; \
	  elif [ ! -e "$$target" ]; then echo "  BROKEN  $$name -> $$(readlink "$$target")"; fail=1; \
	  fi; \
	done; \
	for l in $(TARGET_DIR)/*; do \
	  [ -L "$$l" ] && [ ! -e "$$l" ] || continue; \
	  case "$$(readlink "$$l")" in \
	    $(REPO_DIR)/*) echo "  STALE   $$(basename $$l) -> $$(readlink "$$l") (run 'make relink')"; fail=1 ;; \
	  esac; \
	done; \
	[ $$fail -eq 0 ] && echo "  all $(words $(SKILL_DIRS)) skills linked and healthy" || exit 1
