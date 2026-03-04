# Dev Setup Upgrade — Top-Grade Coding Environment

## TL;DR

> **Quick Summary**: Comprehensive developer-experience overhaul covering git hygiene, AGENTS.md rewrite, test tooling (SimpleCov + Guard), Playwright browser config for agent debugging, mise consolidation, and miscellaneous cleanup (Rubocop, .editorconfig, zombie processes).
> 
> **Deliverables**:
> - Clean git state: 3 merged worktrees deleted, objects packed, .sisyphus gitignored
> - AGENTS.md fully rewritten with React, Python service, auth flow, all controllers
> - Test infra: SimpleCov coverage, Guardfile for auto-run, spec/support helpers
> - Playwright config targeting localhost:3000 with console access for agents
> - Mise managing all runtimes (Ruby + Node + Python) with dev/test/lint tasks
> - .editorconfig, Rubocop auto-fix, stale boulder cleared
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: YES — 4 waves
> **Critical Path**: Task 0 → Wave 1 (parallel) → Wave 2 (parallel) → Wave FINAL

---

## Context

### Original Request
User wants a "top-grade coding setup" — deep review and upgrade of Git workflow, AGENTS.md, testing infrastructure, Playwright browser debugging for AI agents, and mise configuration.

### Interview Summary
**Key Discussions**:
- **Worktrees**: Delete 3 fully merged (photo-view, photo-metadata, location-autocomplete). Review docs-freshness-hook (1 unmerged commit). Keep face-recognition (active work).
- **Browser debugging**: Playwright config + console access. Dev-browser skill exists but needs project-specific config.
- **Mise**: Consolidate everything — move Ruby from rbenv to mise, add task shortcuts.
- **AGENTS.md**: Full rewrite filling all gaps (React, Python service, auth flow, controllers, Procfile, Active Storage).
- **Testing**: Full tooling upgrade — SimpleCov, Guard, spec/support helpers.

**Research Findings**:
- Auth is **passwordless magic-link** (login codes). Dev mode shows code in flash + `X-Login-Code` header. No passwords to document.
- Procfile.dev runs **5 processes**: web, css, vite, jobs (SolidQueue), orientation (Python/uvicorn).
- 140 RSpec examples passing. 18 spec files for 13 controllers + 16 models.
- Playwright browsers already installed. MCP Chrome profile at `~/.cache/ms-playwright/mcp-chrome/`.
- Main is 32 commits ahead of origin. Working tree has uncommitted location-autocomplete changes.
- 6 zombie Vite processes (stopped state) consuming memory.
- Gemfile has duplicate `shoulda-matchers` entry.
- 15 Rubocop offenses (14 auto-fixable).

### Metis Review
**Identified Gaps** (addressed):
- Dirty working tree must be committed/stashed before any work — added as Task 0
- SimpleCov requires modifying `spec_helper.rb` (first line) — explicitly scoped
- `.ruby-version` must stay even after mise manages Ruby (Dockerfile/CI may read it)
- Each worktree must be verified clean before deletion
- `mise.toml` needs to be committed (currently untracked)
- Face-recognition branch: 17 ahead / 34 behind — explicit guardrail: DO NOT TOUCH
- Docs-freshness-hook review: evaluate the pre-commit hook, decide merge or discard

---

## Work Objectives

### Core Objective
Transform the development environment from functional-but-scrappy into a disciplined, fully-documented, tool-optimized setup where both humans and AI agents can work effectively.

### Concrete Deliverables
- Cleaned git state (3 worktrees removed, gc'd, .sisyphus ignored)
- Rewritten `AGENTS.md` (150-250 lines, all gaps filled)
- `Gemfile` updated with `simplecov` (+ duplicate `shoulda-matchers` fixed)
- `.simplecov` config file
- `Guardfile` wired to guard-rspec
- `spec/support/` helper files (factory_bot.rb, coverage.rb)
- `playwright.config.ts` targeting localhost:3000
- `.mise.toml` with all runtimes + task definitions
- `.editorconfig` matching project conventions
- Rubocop auto-fix applied
- Stale `boulder.json` cleared
- Zombie Vite processes killed

### Definition of Done
- [ ] `git worktree list` shows only main + face-recognition
- [ ] `git count-objects -v | grep in-pack` shows >0 (objects packed)
- [ ] `grep '.sisyphus' .gitignore` returns match
- [ ] `grep -c 'React' AGENTS.md` returns ≥1
- [ ] `grep -c 'orientation' AGENTS.md` returns ≥1
- [ ] `grep -c 'passwordless\|login.code\|magic' AGENTS.md` returns ≥1
- [ ] `COVERAGE=true bundle exec rspec` generates `coverage/index.html`
- [ ] `bundle exec guard list` succeeds
- [ ] `npx playwright test --list` succeeds (config valid)
- [ ] `mise run test` executes rspec
- [ ] `mise run lint` executes rubocop
- [ ] `bin/rubocop` returns 0 auto-fixable offenses

### Must Have
- All 3 merged worktrees deleted via `git worktree remove`
- AGENTS.md documents: React components, Python orientation service, passwordless auth flow, all controllers, Procfile.dev processes, Active Storage variants
- SimpleCov configured and generating HTML reports
- Guardfile that auto-runs relevant specs on file changes
- Playwright config with baseURL `http://localhost:3000`
- Mise tasks: `dev`, `test`, `lint`, `console`
- `.editorconfig` with 2-space indent for Ruby/JS, LF line endings

### Must NOT Have (Guardrails)
- **DO NOT** delete or modify the `face-recognition` worktree or branch
- **DO NOT** modify any application code (models, controllers, views, routes, migrations)
- **DO NOT** write actual test cases — infrastructure/config only
- **DO NOT** push to origin/main (32 unpushed commits — user decides separately)
- **DO NOT** remove `.ruby-version` file (Dockerfile and CI may read it)
- **DO NOT** remove rbenv — just ensure mise takes priority in PATH
- **DO NOT** modify `config/credentials.yml.enc` or any secrets
- **DO NOT** document the face-recognition feature in AGENTS.md (not merged to main)
- **DO NOT** expand AGENTS.md beyond 250 lines
- **DO NOT** add gems beyond `simplecov` without explicit approval
- **DO NOT** create actual Playwright test files (config only)
- **DO NOT** touch application code while doing Rubocop fixes (auto-fix only, abort if any fix changes logic)

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (RSpec + FactoryBot)
- **Automated tests**: None (this plan is infrastructure work, not feature work)
- **Framework**: RSpec (existing — verify it still passes after changes)

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Git operations**: Use Bash — run git commands, verify output
- **Config files**: Use Bash — verify file exists, grep for required content
- **Test infra**: Use Bash — run `bundle exec rspec`, verify output
- **Playwright**: Use Bash — run `npx playwright test --list`, verify config loads
- **Mise**: Use Bash — run `mise run {task}`, verify execution

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 0 (Prerequisite — must complete first):
└── Task 0: Commit dirty working tree + kill zombie processes [quick]

Wave 1 (After Wave 0 — independent cleanup, MAX PARALLEL):
├── Task 1: Git worktree cleanup + gc + .sisyphus gitignore [quick]
├── Task 2: Rubocop auto-fix + fix duplicate shoulda-matchers [quick]
├── Task 3: Add .editorconfig [quick]
├── Task 4: Clear stale boulder.json [quick]
└── Task 5: Review docs-freshness-hook branch [quick]

Wave 2 (After Wave 1 — tooling + docs, depends on clean git state):
├── Task 6: AGENTS.md full rewrite [writing]
├── Task 7: Test infra — SimpleCov + Guardfile + spec/support [unspecified-high]
├── Task 8: Playwright config for localhost [quick]
└── Task 9: Mise consolidation — runtimes + tasks [unspecified-high]

Wave FINAL (After ALL tasks — independent review):
├── Task F1: Plan compliance audit [oracle]
├── Task F2: Code quality review [unspecified-high]
├── Task F3: Real manual QA [unspecified-high]
└── Task F4: Scope fidelity check [deep]

Critical Path: Task 0 → Task 1 → Task 6 (AGENTS.md needs clean git state)
Parallel Speedup: ~60% faster than sequential
Max Concurrent: 5 (Wave 1)
```

### Dependency Matrix

| Task | Depends On | Blocks |
|------|-----------|--------|
| 0 | — | 1, 2, 3, 4, 5 |
| 1 | 0 | 6 |
| 2 | 0 | 6 |
| 3 | 0 | — |
| 4 | 0 | — |
| 5 | 0 | 6 (if hook is merged) |
| 6 | 1, 2, 5 | F1-F4 |
| 7 | 0 | F1-F4 |
| 8 | 0 | F1-F4 |
| 9 | 0 | F1-F4 |
| F1-F4 | ALL | — |

### Agent Dispatch Summary

- **Wave 0**: **1** — T0 → `quick`
- **Wave 1**: **5** — T1-T5 → `quick`
- **Wave 2**: **4** — T6 → `writing`, T7 → `unspecified-high`, T8 → `quick`, T9 → `unspecified-high`
- **FINAL**: **4** — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [ ] 0. Commit Dirty Working Tree + Kill Zombie Processes

  **What to do**:
  - Review current `git status` — there are staged + unstaged changes from location-autocomplete work
  - Stage all meaningful changes: `app/controllers/locations_controller.rb`, `app/javascript/controllers/location_autocomplete_controller.js`, `app/models/location.rb`, `.sisyphus/boulder.json`
  - Commit with message: `chore(git): commit pending location-autocomplete changes`
  - Kill 6 zombie Vite processes (stopped state, consuming memory): `pkill -f 'vite.*--mode development' || true` — verify with `ps aux | grep -c '[v]ite'`
  - Verify: `git status` shows clean working tree (only untracked .sisyphus/evidence files remain)

  **Must NOT do**:
  - Do NOT commit `config/credentials.yml.enc` changes (sensitive)
  - Do NOT stage `package-lock.json` or `package.json` if they only have lockfile churn
  - Do NOT modify any application code while doing this

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`git-master`]
    - `git-master`: Git operations requiring careful staging and commit handling
  - **Skills Evaluated but Omitted**:
    - None — this is purely a git operation

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 0 (prerequisite)
  - **Blocks**: Tasks 1, 2, 3, 4, 5 (all Wave 1)
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `git log --oneline -5` — Recent commit style: `type(scope): description`

  **Current State References**:
  - `git status` output — Shows: M .sisyphus/boulder.json, M app/controllers/locations_controller.rb, M app/javascript/controllers/location_autocomplete_controller.js, M app/models/location.rb, M config/credentials.yml.enc, M package-lock.json, M package.json, plus 24+ untracked .sisyphus/evidence/ files
  - `ps aux | grep vite` — 6 stopped Vite processes from prior worktree dev servers

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Working tree is clean after commit
    Tool: Bash
    Preconditions: Dirty working tree with staged + unstaged changes
    Steps:
      1. Run `git status --porcelain | grep -E '^[MADRC]' | wc -l`
      2. Assert output is `0` (no staged/unstaged tracked file changes)
      3. Run `git log --oneline -1`
      4. Assert contains `chore(git): commit pending`
    Expected Result: Zero modified tracked files, clean commit at HEAD
    Failure Indicators: Any `M`, `A`, `D` entries in git status for tracked files
    Evidence: .sisyphus/evidence/task-0-git-clean.txt

  Scenario: Zombie Vite processes are killed
    Tool: Bash
    Preconditions: 6 stopped Vite processes
    Steps:
      1. Run `ps aux | grep '[v]ite.*--mode development' | grep -c ' T'`
      2. Assert output is `0`
    Expected Result: No stopped Vite processes remain
    Failure Indicators: Any Vite process in T (stopped) state
    Evidence: .sisyphus/evidence/task-0-no-zombies.txt
  ```

  **Commit**: YES
  - Message: `chore(git): commit pending location-autocomplete changes`
  - Files: Staged tracked changes (excluding credentials.yml.enc)
  - Pre-commit: `bundle exec rspec` (verify nothing is broken)

- [ ] 1. Git Worktree Cleanup + GC + .sisyphus Gitignore

  **What to do**:
  - Verify each worktree is clean before deletion:
    - `git -C /home/pippin/projects/photos-photo-view status --porcelain`
    - `git -C /home/pippin/projects/photos-photo-metadata status --porcelain`
    - `git -C /home/pippin/projects/photos-location-autocomplete status --porcelain`
  - Remove 3 merged worktrees (in order):
    - `git worktree remove /home/pippin/projects/photos-photo-view`
    - `git worktree remove /home/pippin/projects/photos-photo-metadata`
    - `git worktree remove /home/pippin/projects/photos-location-autocomplete`
  - Delete the local branches:
    - `git branch -d photo-view photo-metadata location-autocomplete`
  - Run garbage collection: `git gc --prune=now`
  - Add `.sisyphus/` to `.gitignore` (append at end, with comment header)
  - Verify: `git worktree list` shows only main + face-recognition + docs-freshness-hook

  **Must NOT do**:
  - Do NOT delete or touch the `face-recognition` worktree or branch
  - Do NOT delete the `docs-freshness-hook` worktree (reviewed in Task 5)
  - Do NOT use `rm -rf` — always use `git worktree remove`
  - Do NOT run `git push` to origin

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`git-master`]
    - `git-master`: Worktree management, branch deletion, gc operations
  - **Skills Evaluated but Omitted**:
    - None — purely git operations

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 2, 3, 4, 5)
  - **Blocks**: Task 6 (AGENTS.md needs to reflect accurate git state)
  - **Blocked By**: Task 0

  **References**:

  **Current State References**:
  - `git worktree list` — Shows 6 worktrees: main, photo-view, photo-metadata, location-autocomplete, docs-freshness-hook, face-recognition
  - `git branch -a` — Local branches: main, photo-view, photo-metadata, docs-freshness-hook, location-autocomplete, face-recognition. Remote: origin/main only
  - `git count-objects -v` — 1601 loose objects, 0 packs
  - Worktree disk usage: photo-view 122M, photo-metadata 52M, location-autocomplete 63M, face-recognition 81M, docs-freshness-hook 2.3M

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Merged worktrees are deleted
    Tool: Bash
    Preconditions: 6 worktrees exist
    Steps:
      1. Run `git worktree list`
      2. Assert output contains exactly 3 lines (main, face-recognition, docs-freshness-hook)
      3. Run `ls -d /home/pippin/projects/photos-photo-view 2>/dev/null`
      4. Assert directory does NOT exist
      5. Run `ls -d /home/pippin/projects/photos-photo-metadata 2>/dev/null`
      6. Assert directory does NOT exist
      7. Run `ls -d /home/pippin/projects/photos-location-autocomplete 2>/dev/null`
      8. Assert directory does NOT exist
    Expected Result: Only main, face-recognition, and docs-freshness-hook worktrees remain. ~237MB disk freed.
    Failure Indicators: Deleted worktree directories still exist, or worktree list shows >3 entries
    Evidence: .sisyphus/evidence/task-1-worktrees.txt

  Scenario: Git objects are packed and branches deleted
    Tool: Bash
    Preconditions: 1601 loose objects, 0 packs
    Steps:
      1. Run `git count-objects -v`
      2. Assert `in-pack` value is >0 (objects packed)
      3. Run `git branch | grep -E 'photo-view|photo-metadata|location-autocomplete'`
      4. Assert no output (branches deleted)
    Expected Result: Objects packed, dead branches removed
    Failure Indicators: in-pack still 0, or deleted branch names still listed
    Evidence: .sisyphus/evidence/task-1-gc.txt

  Scenario: .sisyphus is gitignored
    Tool: Bash
    Preconditions: .sisyphus/ not in .gitignore
    Steps:
      1. Run `grep '.sisyphus' .gitignore`
      2. Assert output contains `.sisyphus/`
      3. Run `git status --porcelain .sisyphus/`
      4. Assert no output (all .sisyphus files are now ignored)
    Expected Result: .sisyphus directory fully gitignored
    Failure Indicators: .sisyphus files still show in git status
    Evidence: .sisyphus/evidence/task-1-gitignore.txt
  ```

  **Commit**: YES
  - Message: `chore(git): remove merged worktrees, gc, gitignore .sisyphus`
  - Files: `.gitignore`
  - Pre-commit: none (git operations don't need test run)

- [ ] 2. Rubocop Auto-Fix + Fix Duplicate shoulda-matchers

  **What to do**:
  - Fix duplicate `shoulda-matchers` in Gemfile:
    - Open `Gemfile`, find the `group :test` block
    - Remove the duplicate `gem "shoulda-matchers"` line (appears twice)
    - Run `bundle install` to regenerate lockfile
  - Run `bin/rubocop -A` to auto-fix the 14 correctable offenses
  - Verify: `bin/rubocop` shows ≤1 offense (the 1 non-auto-fixable one)
  - Run `bundle exec rspec` to verify no test regressions

  **Must NOT do**:
  - Do NOT manually fix the 1 non-auto-fixable offense
  - Do NOT add new Rubocop rules or overrides to `.rubocop.yml`
  - Do NOT modify application logic — only style changes from auto-fix
  - If `rubocop -A` changes anything that looks like a logic change, `git checkout` that file and skip it

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `git-master`: Not needed — simple commit after auto-fix

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 3, 4, 5)
  - **Blocks**: Task 6 (AGENTS.md should reflect clean lint state)
  - **Blocked By**: Task 0

  **References**:

  **Current State References**:
  - `bin/rubocop` output — 108 files inspected, 15 offenses detected, 14 auto-correctable
  - Offenses are in: `spec/factories.rb` (string quotes), `db/seeds.rb` (array brackets, trailing commas)
  - `Gemfile` lines ~44-46 — `gem "shoulda-matchers"` appears twice in `:test` group

  **API/Type References**:
  - `rubocop-rails-omakase` — The inherited config that defines the rules

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Rubocop offenses reduced
    Tool: Bash
    Preconditions: 15 offenses, 14 auto-correctable
    Steps:
      1. Run `bin/rubocop -f simple 2>&1 | tail -1`
      2. Assert output shows ≤1 offense (the non-auto-fixable one)
      3. Run `bin/rubocop -f simple 2>&1 | grep -c 'Correctable'`
      4. Assert output is `0` (no remaining auto-fixable offenses)
    Expected Result: All auto-fixable offenses resolved
    Failure Indicators: More than 1 offense, or any `[Correctable]` markers remain
    Evidence: .sisyphus/evidence/task-2-rubocop.txt

  Scenario: Duplicate gem removed and tests still pass
    Tool: Bash
    Preconditions: shoulda-matchers appears twice in Gemfile
    Steps:
      1. Run `grep -c 'shoulda-matchers' Gemfile`
      2. Assert output is `1` (single entry)
      3. Run `bundle exec rspec 2>&1 | tail -3`
      4. Assert output contains `0 failures`
    Expected Result: Single shoulda-matchers entry, all 140 examples pass
    Failure Indicators: Duplicate still present, or test failures
    Evidence: .sisyphus/evidence/task-2-tests.txt
  ```

  **Commit**: YES (two separate commits)
  - Message 1: `fix(gemfile): remove duplicate shoulda-matchers`
  - Files 1: `Gemfile`, `Gemfile.lock`
  - Pre-commit 1: `bundle exec rspec`
  - Message 2: `style: auto-fix rubocop offenses`
  - Files 2: All auto-fixed files
  - Pre-commit 2: `bin/rubocop`

- [ ] 3. Add .editorconfig

  **What to do**:
  - Create `.editorconfig` at project root with settings matching existing conventions:
    - `root = true`
    - Default: `indent_style = space`, `indent_size = 2`, `end_of_line = lf`, `charset = utf-8`, `trim_trailing_whitespace = true`, `insert_final_newline = true`
    - `[*.rb]`: indent_size = 2
    - `[*.{js,ts,tsx,jsx}]`: indent_size = 2
    - `[*.{yml,yaml}]`: indent_size = 2
    - `[*.{css,scss}]`: indent_size = 2
    - `[*.md]`: trim_trailing_whitespace = false
    - `[Makefile]`: indent_style = tab
  - Verify: File exists and is well-formed

  **Must NOT do**:
  - Do NOT override any existing code formatting — this just codifies what already exists

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 4, 5)
  - **Blocks**: None
  - **Blocked By**: Task 0

  **References**:
  - `.rubocop.yml` — Inherits `rubocop-rails-omakase` which enforces 2-space indent
  - `vite.config.ts` — Uses 2-space indent (JS convention)
  - All `.rb` files — 2-space indent throughout

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: .editorconfig exists with correct settings
    Tool: Bash
    Preconditions: No .editorconfig exists
    Steps:
      1. Run `cat .editorconfig`
      2. Assert contains `root = true`
      3. Assert contains `indent_size = 2`
      4. Assert contains `end_of_line = lf`
      5. Assert contains `trim_trailing_whitespace = true`
      6. Run `grep -c '\[\*\.md\]' .editorconfig`
      7. Assert output is `1` (markdown section exists)
    Expected Result: Well-formed .editorconfig matching project conventions
    Failure Indicators: File missing, wrong indent settings, missing sections
    Evidence: .sisyphus/evidence/task-3-editorconfig.txt
  ```

  **Commit**: YES
  - Message: `chore: add .editorconfig`
  - Files: `.editorconfig`
  - Pre-commit: none

- [ ] 4. Clear Stale boulder.json

  **What to do**:
  - Read `.sisyphus/boulder.json` — currently points to `photo-metadata` plan which is fully merged
  - Delete the file: `rm .sisyphus/boulder.json`
  - This prevents Sisyphus from trying to resume a completed plan
  - Note: .sisyphus/ will be gitignored by Task 1, so no commit needed for this file itself

  **Must NOT do**:
  - Do NOT delete any other .sisyphus files (plans, notepads, evidence)

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 5)
  - **Blocks**: None
  - **Blocked By**: Task 0

  **References**:
  - `.sisyphus/boulder.json` — Contains: `{"active_plan": "...photo-metadata.md", "plan_name": "photo-metadata"}`
  - photo-metadata branch is 0 commits ahead of main — fully merged, plan is complete

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Stale boulder is cleared
    Tool: Bash
    Preconditions: boulder.json points to merged plan
    Steps:
      1. Run `cat .sisyphus/boulder.json 2>&1`
      2. Assert output contains "No such file" or file doesn't exist
    Expected Result: boulder.json is deleted
    Failure Indicators: File still exists with stale content
    Evidence: .sisyphus/evidence/task-4-boulder.txt
  ```

  **Commit**: NO (file is in gitignored .sisyphus/)

- [ ] 5. Review docs-freshness-hook Branch

  **What to do**:
  - Examine the 1 unmerged commit on `docs-freshness-hook` branch:
    - `git log main..docs-freshness-hook --oneline` — shows: `d99886a feat(hooks): add pre-commit docs-freshness check`
    - `git diff main..docs-freshness-hook` — read the actual hook implementation
  - Evaluate the hook:
    - What does it check? (docs freshness, probably checks if .md files are outdated)
    - Is it compatible with our current workflow?
    - Is it well-implemented?
  - Decision tree:
    - If the hook is useful and clean → Cherry-pick the commit to main: `git cherry-pick d99886a`
    - If the hook needs work → Note what needs changing in evidence file, do NOT merge
    - If the hook is not useful → Delete worktree + branch: `git worktree remove /home/pippin/projects/photos-docs-freshness-hook && git branch -D docs-freshness-hook`
  - Record the decision and rationale in evidence

  **Must NOT do**:
  - Do NOT blindly merge without reviewing the implementation
  - Do NOT modify the hook code — either take it as-is or reject it

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: [`git-master`]
    - `git-master`: Branch comparison, cherry-pick, worktree management

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 1 (with Tasks 1, 2, 3, 4)
  - **Blocks**: Task 6 (if hook is merged, AGENTS.md should mention pre-commit hooks)
  - **Blocked By**: Task 0

  **References**:

  **Current State References**:
  - `docs-freshness-hook` branch — 1 commit ahead of main, 23 behind
  - The commit: `d99886a feat(hooks): add pre-commit docs-freshness check`
  - `git diff main..docs-freshness-hook` — Will show the actual hook file content

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Hook is reviewed and decision is recorded
    Tool: Bash
    Preconditions: docs-freshness-hook branch exists with 1 unmerged commit
    Steps:
      1. Run `git diff main..docs-freshness-hook --stat`
      2. Record which files the hook touches
      3. Read the hook implementation
      4. Record decision (merge/reject/needs-work) with rationale in evidence
      5. Execute the decision (cherry-pick OR delete worktree+branch OR leave for later)
      6. Run `git worktree list` to verify final state
    Expected Result: Clear documented decision about the hook, action taken
    Failure Indicators: No decision recorded, hook merged without review
    Evidence: .sisyphus/evidence/task-5-hook-review.txt

  Scenario: If merged — hook works correctly
    Tool: Bash
    Preconditions: Hook was cherry-picked to main
    Steps:
      1. Run `ls .git/hooks/pre-commit` or check if hook is in the committed codebase
      2. If hook is file-based, verify it's executable
      3. Make a trivial change and attempt commit to verify hook runs
    Expected Result: Hook executes without error on normal commit
    Failure Indicators: Hook blocks commits incorrectly or errors out
    Evidence: .sisyphus/evidence/task-5-hook-test.txt
  ```

  **Commit**: CONDITIONAL (only if cherry-picking the hook commit)
  - Message: (the cherry-picked commit message)
  - Files: Whatever the hook commit touches
  - Pre-commit: `bundle exec rspec`


- [ ] 6. AGENTS.md Full Rewrite

  **What to do**:
  - Read the current `AGENTS.md` (101 lines) completely
  - Rewrite it to fill all identified gaps while keeping the good existing structure
  - Target: 150-250 lines. Concise but complete.
  - Sections to include (in order):
    1. **Header**: Project name + 1-line description
    2. **Project Stack**: Update to include React, Python orientation service
    3. **Architecture Overview** (NEW): Brief description of how Rails + Vite + Stimulus + React coexist. Mention the Python microservice.
    4. **Development Server**: Document Procfile.dev with ALL 5 processes (web, css, vite, jobs, orientation). Explain `bin/dev` runs foreman.
    5. **Authentication** (NEW): Explain passwordless magic-link flow. In dev mode, login code appears in flash message and `X-Login-Code` response header. Document the exact login steps for agents:
       - Visit `/session/new`
       - Enter email (e.g., `alex@example.com`)
       - Submit → redirects to `/session/login_code`
       - In dev: code is in the flash or `X-Login-Code` header
       - Enter code → authenticated
    6. **Database**: Keep existing, add note about structure.sql
    7. **Testing**: Commands + note about FactoryBot, WebMock, Shoulda
    8. **Linting**: Keep existing
    9. **Code Style & Conventions**: Keep existing Ruby/JS sections, ADD React section:
       - React is used ONLY for the photo viewer component (`app/javascript/components/PhotoView/`)
       - Stimulus bridge pattern: `photo_view_controller.js` bootstraps React into a Turbo-managed page
       - No semicolons in JSX files either
    10. **Key Domain Concepts**: Keep existing, ensure accuracy against current main
    11. **Controllers** (NEW): List ALL controllers with 1-line description
    12. **Services** (NEW): Document orientation Python service (port 8150, uvicorn, ONNX models)
    13. **Active Storage** (NEW): Variants (:thumb, :medium, :large), storage config
    14. **Directory Structure**: Update with `app/javascript/components/`, `services/orientation/`
    15. **Seed Data**: Update with auth instructions (passwordless flow, not passwords)
  - Reference current `AGENTS.md` for tone and formatting style
  - Reference `app/controllers/` listing for complete controller inventory
  - Reference `Procfile.dev` for exact process definitions
  - Reference `app/javascript/controllers/` and `app/javascript/components/` for frontend architecture

  **Must NOT do**:
  - Do NOT exceed 250 lines (prevents documentation bloat)
  - Do NOT document the face-recognition feature (not on main)
  - Do NOT document every route — reference `rails routes` instead
  - Do NOT document every model relation — reference `db/structure.sql`
  - Do NOT add deployment/production instructions (out of scope)
  - Do NOT document Stimulus controllers individually (just list them)

  **Recommended Agent Profile**:
  - **Category**: `writing`
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `frontend-ui-ux`: Not needed — this is documentation, not UI work

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 7, 8, 9)
  - **Blocks**: F1-F4 (final verification needs accurate AGENTS.md)
  - **Blocked By**: Tasks 1, 2, 5 (needs clean git state and accurate project state)

  **References**:

  **Pattern References** (existing documentation to preserve):
  - `AGENTS.md:1-101` — Current document. Preserve tone, header style, code block formatting.
  - `AGENTS.md:76-87` — Key Domain Concepts section is well-written. Keep or refine, don't rewrite from scratch.

  **Content Source References** (what to document):
  - `Procfile.dev` — All 5 process definitions: `web: bin/rails server -p 3000 -b 0.0.0.0`, `css: bin/rails dartsass:watch`, `vite: bin/vite dev`, `jobs: bin/jobs`, `orientation: services/orientation/.venv/bin/uvicorn ...`
  - `app/controllers/` — 14 controllers: application, contributions, events, families, locations, people, photo_faces, photo_people, photos, sessions (+ sessions/login_codes), site, uploads
  - `app/javascript/controllers/` — 7 Stimulus controllers: application, face_tagging, file_timestamps, index, location_autocomplete, person_autocomplete, photo_view
  - `app/javascript/components/` — React components for PhotoView (if directory exists)
  - `services/orientation/` — Python FastAPI service with ONNX models
  - `app/controllers/sessions_controller.rb` and `app/controllers/sessions/login_codes_controller.rb` — Auth flow implementation
  - `config/routes.rb` — Route structure for understanding URL patterns
  - `spec/factories.rb` — Factory definitions showing model relationships

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: AGENTS.md covers all required topics
    Tool: Bash
    Preconditions: AGENTS.md rewritten
    Steps:
      1. Run `wc -l AGENTS.md` — assert between 150 and 250
      2. Run `grep -c 'React' AGENTS.md` — assert ≥1
      3. Run `grep -c 'orientation' AGENTS.md` — assert ≥1
      4. Run `grep -c 'passwordless\|login.code\|magic' AGENTS.md` — assert ≥1
      5. Run `grep -c 'Procfile' AGENTS.md` — assert ≥1
      6. Run `grep -c 'uvicorn\|8150' AGENTS.md` — assert ≥1
      7. Run `grep -c 'uploads_controller\|UploadsController' AGENTS.md` — assert ≥1
      8. Run `grep -c 'Active.Storage\|active_storage' AGENTS.md` — assert ≥1
      9. Run `grep -c 'SimpleCov\|Guard' AGENTS.md` — assert ≥1 (if test tools added by then)
    Expected Result: All topic areas represented in the document
    Failure Indicators: Any grep returns 0
    Evidence: .sisyphus/evidence/task-6-agents-topics.txt

  Scenario: AGENTS.md is not bloated
    Tool: Bash
    Preconditions: AGENTS.md rewritten
    Steps:
      1. Run `wc -l AGENTS.md`
      2. Assert line count is between 150 and 250
      3. Run `grep -c '^#' AGENTS.md`
      4. Assert section headers are ≤20 (reasonable structure)
    Expected Result: Concise, well-structured document
    Failure Indicators: >250 lines or >20 section headers (over-documented)
    Evidence: .sisyphus/evidence/task-6-agents-size.txt
  ```

  **Commit**: YES
  - Message: `docs(agents): full rewrite — add React, auth flow, Python service, all controllers`
  - Files: `AGENTS.md`
  - Pre-commit: none

- [ ] 7. Test Infrastructure — SimpleCov + Guardfile + spec/support

  **What to do**:
  - **Add SimpleCov to Gemfile** (in `:test` group):
    - `gem "simplecov", require: false`
  - **Run `bundle install`** to install the gem
  - **Create `spec/support/coverage.rb`**:
    ```ruby
    require "simplecov"
    SimpleCov.start "rails" do
      add_filter "/spec/"
      add_filter "/config/"
      add_filter "/db/"
      minimum_coverage 0  # Don't fail on low coverage initially
    end
    ```
  - **Modify `spec/spec_helper.rb`** — Add `require_relative 'support/coverage'` as the VERY FIRST LINE (before any other requires). SimpleCov MUST load before application code.
  - **Create `Guardfile`**:
    ```ruby
    guard :rspec, cmd: "bundle exec rspec" do
      watch(%r{^spec/.+_spec\.rb$})
      watch(%r{^app/(.+)\.rb$}) { |m| "spec/#{m[1]}_spec.rb" }
      watch(%r{^app/models/(.+)\.rb$}) { |m| "spec/models/#{m[1]}_spec.rb" }
      watch(%r{^app/controllers/(.+)\.rb$}) { |m| "spec/requests/#{m[1].sub('_controller', '')}_spec.rb" }
      watch(%r{^app/services/(.+)\.rb$}) { |m| "spec/services/#{m[1]}_spec.rb" }
      watch(%r{^app/jobs/(.+)\.rb$}) { |m| "spec/jobs/#{m[1]}_spec.rb" }
      watch("spec/rails_helper.rb") { "spec" }
      watch("spec/spec_helper.rb") { "spec" }
      watch("spec/factories.rb") { "spec" }
    end
    ```
  - **Create `spec/support/factory_bot.rb`** (extract from rails_helper for cleanliness):
    ```ruby
    RSpec.configure do |config|
      config.include FactoryBot::Syntax::Methods
    end
    ```
  - **Update `spec/rails_helper.rb`**: Add `Dir[Rails.root.join('spec/support/**/*.rb')].sort.each { |f| require f }` to auto-load support files. Remove the inline `config.include FactoryBot::Syntax::Methods` (now in support file).
  - **Add `coverage/` to `.gitignore`** (SimpleCov output directory)
  - **Verify**: `bundle exec rspec` still passes with 140 examples, 0 failures
  - **Verify**: `COVERAGE=true bundle exec rspec` generates `coverage/index.html`

  **Must NOT do**:
  - Do NOT write actual test cases — infrastructure only
  - Do NOT modify any existing spec files (except `spec_helper.rb` for SimpleCov require and `rails_helper.rb` for support auto-load)
  - Do NOT set a minimum coverage threshold that would cause failures
  - Do NOT add Capybara (not requested for this plan)

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not relevant — this is Ruby test infra, not browser testing

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 6, 8, 9)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 0 (clean state), Task 2 (Gemfile changes should be sequential)

  **References**:

  **Pattern References**:
  - `spec/rails_helper.rb:1-35` — Current helper setup. Lines 21-27: FactoryBot config (to be moved to support file). Line 1: `require 'spec_helper'` (SimpleCov must go before this).
  - `spec/spec_helper.rb:1-40` — Current helper. SimpleCov require goes as first line.
  - `Gemfile:35-50` — Test group where SimpleCov should be added. Note: duplicate shoulda-matchers at ~line 44+46 (fixed by Task 2).

  **External References**:
  - SimpleCov docs: https://github.com/simplecov-ruby/simplecov — Rails setup, `SimpleCov.start 'rails'`
  - Guard-RSpec docs: https://github.com/guard/guard-rspec — Guardfile syntax, watch patterns

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: SimpleCov generates coverage report
    Tool: Bash
    Preconditions: SimpleCov gem installed, spec_helper.rb updated
    Steps:
      1. Run `rm -rf coverage/` (clean slate)
      2. Run `COVERAGE=true bundle exec rspec 2>&1 | tail -5`
      3. Assert output contains `0 failures`
      4. Run `ls coverage/index.html`
      5. Assert file exists
      6. Run `grep -c 'SimpleCov' coverage/index.html`
      7. Assert output > 0 (valid SimpleCov report)
    Expected Result: HTML coverage report generated at coverage/index.html
    Failure Indicators: coverage/ directory empty, rspec failures
    Evidence: .sisyphus/evidence/task-7-simplecov.txt

  Scenario: Guard is configured and lists watchers
    Tool: Bash
    Preconditions: Guardfile created
    Steps:
      1. Run `cat Guardfile`
      2. Assert contains `guard :rspec`
      3. Run `bundle exec guard list 2>&1`
      4. Assert output contains `rspec` (guard-rspec plugin listed)
    Expected Result: Guard configured with rspec watchers
    Failure Indicators: guard list fails or doesn't show rspec
    Evidence: .sisyphus/evidence/task-7-guard.txt

  Scenario: spec/support files are auto-loaded
    Tool: Bash
    Preconditions: support files created, rails_helper updated
    Steps:
      1. Run `ls spec/support/`
      2. Assert contains `coverage.rb` and `factory_bot.rb`
      3. Run `bundle exec rspec 2>&1 | tail -3`
      4. Assert `0 failures` (support files load correctly)
      5. Run `grep -c 'support' spec/rails_helper.rb`
      6. Assert > 0 (auto-load line present)
    Expected Result: Support files exist and are auto-loaded by rails_helper
    Failure Indicators: Missing files, load errors, test failures
    Evidence: .sisyphus/evidence/task-7-support.txt
  ```

  **Commit**: YES
  - Message: `chore(test): add SimpleCov coverage, Guardfile, spec/support helpers`
  - Files: `Gemfile`, `Gemfile.lock`, `.simplecov` (if used), `Guardfile`, `spec/support/coverage.rb`, `spec/support/factory_bot.rb`, `spec/spec_helper.rb`, `spec/rails_helper.rb`, `.gitignore`
  - Pre-commit: `bundle exec rspec`


- [ ] 8. Playwright Config for Localhost + Console Access

  **What to do**:
  - **Create `playwright.config.ts`** at project root:
    ```typescript
    import { defineConfig } from '@playwright/test'

    export default defineConfig({
      testDir: './spec/e2e',
      timeout: 30_000,
      retries: 0,
      use: {
        baseURL: 'http://localhost:3000',
        headless: true,
        screenshot: 'only-on-failure',
        trace: 'retain-on-failure',
        // Enable console log capture for debugging
        contextOptions: {
          logger: {
            isEnabled: () => true,
            log: (name, severity, message) => console.log(`[${severity}] ${name}: ${message}`),
          },
        },
      },
      // Don't auto-start dev server — agents should use existing bin/dev
      // webServer: { command: 'bin/dev', url: 'http://localhost:3000/up', timeout: 30_000 },
      projects: [
        {
          name: 'chromium',
          use: {
            browserName: 'chromium',
            // Capture browser console output
            launchOptions: {
              args: ['--enable-logging'],
            },
          },
        },
      ],
    })
    ```
  - **Create `spec/e2e/` directory** (empty, for future test files)
  - **Ensure Playwright browsers are up to date**: `npx playwright install chromium` (already installed but verify)
  - **Create a `.playwright/` gitignore entry** in `.gitignore` for test artifacts
  - **Verify**: `npx playwright test --list` succeeds (config is valid, even with 0 test files)
  - **Note for AGENTS.md (Task 6)**: The `dev-browser` and `playwright` skills in OpenCode can now target localhost:3000. Agents can:
    - Navigate pages via Playwright MCP
    - Capture screenshots for visual debugging
    - Read browser console errors for JavaScript debugging
    - Interact with forms and UI elements

  **Must NOT do**:
  - Do NOT write actual E2E test files — config only + empty directory
  - Do NOT install browsers beyond chromium (already installed)
  - Do NOT add webServer auto-start (agents manage their own server lifecycle)
  - Do NOT modify Vite config or Rails config for Playwright

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `playwright`: Not needed for writing config — that skill is for running browser automation

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 6, 7, 9)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 0

  **References**:

  **Current State References**:
  - `package.json` — `@playwright/test` v1.58.2 already installed
  - `~/.cache/ms-playwright/` — Chromium browsers already downloaded (v1200 + v1208)
  - `~/.cache/ms-playwright/mcp-chrome/` — MCP Chrome profile exists for persistent browser state
  - No existing `playwright.config.ts` — creating from scratch

  **External References**:
  - Playwright config docs: https://playwright.dev/docs/test-configuration — baseURL, projects, webServer options
  - Playwright console capture: https://playwright.dev/docs/api/class-consolemessage — How to capture console.log from browser

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Playwright config loads successfully
    Tool: Bash
    Preconditions: playwright.config.ts created
    Steps:
      1. Run `npx playwright test --list 2>&1`
      2. Assert output does NOT contain 'Error' or 'could not'
      3. Run `grep 'baseURL' playwright.config.ts`
      4. Assert contains 'localhost:3000'
    Expected Result: Config parses without errors, targets localhost
    Failure Indicators: Parse errors, wrong baseURL
    Evidence: .sisyphus/evidence/task-8-playwright-config.txt

  Scenario: spec/e2e directory exists for future tests
    Tool: Bash
    Preconditions: Directory created
    Steps:
      1. Run `ls -d spec/e2e`
      2. Assert directory exists
      3. Run `grep 'playwright\|spec/e2e' .gitignore`
      4. Assert Playwright artifacts are gitignored
    Expected Result: E2E directory ready, artifacts ignored
    Failure Indicators: Directory missing, no gitignore entry
    Evidence: .sisyphus/evidence/task-8-e2e-dir.txt
  ```

  **Commit**: YES
  - Message: `chore(playwright): add config targeting localhost:3000 with console capture`
  - Files: `playwright.config.ts`, `spec/e2e/.gitkeep`, `.gitignore`
  - Pre-commit: `npx playwright test --list`

- [ ] 9. Mise Consolidation — All Runtimes + Task Shortcuts

  **What to do**:
  - **Rewrite `.mise.toml`** (currently only has `node = "24"`) to manage ALL runtimes:
    ```toml
    [tools]
    ruby = "3.2.2"
    node = "24"
    python = "3.12"

    [tasks.dev]
    description = "Start development server (all processes)"
    run = "bin/dev"

    [tasks.test]
    description = "Run full test suite"
    run = "bundle exec rspec"

    [tasks."test:watch"]
    description = "Run tests on file changes (Guard)"
    run = "bundle exec guard"

    [tasks.lint]
    description = "Run Rubocop linter"
    run = "bin/rubocop"

    [tasks."lint:fix"]
    description = "Auto-fix Rubocop offenses"
    run = "bin/rubocop -A"

    [tasks.console]
    description = "Open Rails console"
    run = "bin/rails console"

    [tasks."db:reset"]
    description = "Reset database and seed"
    run = "bin/rails db:reset"

    [tasks."db:migrate"]
    description = "Run database migrations"
    run = "bin/rails db:migrate"
    ```
  - **Verify mise picks up Ruby**: `mise current` should show ruby 3.2.2
  - **Keep `.ruby-version`** file (Dockerfile, CI, editors may read it). Mise and .ruby-version will agree (both 3.2.2).
  - **Do NOT remove rbenv** — it can coexist. Mise takes priority if it's first in PATH (which it is, since `~/.local/share/mise` is before `~/.rbenv/shims`).
  - **Verify PATH priority**: Run `which ruby` — should point to mise-managed Ruby, not rbenv shim
  - **Test all tasks**:
    - `mise run test` → runs rspec
    - `mise run lint` → runs rubocop
    - `mise run console` → opens rails console (Ctrl-D to exit)
    - `mise tasks` → lists all defined tasks

  **Must NOT do**:
  - Do NOT delete `.ruby-version` (Dockerfile reads it)
  - Do NOT uninstall rbenv
  - Do NOT change Ruby version (must stay 3.2.2)
  - Do NOT change Node version (must stay 24)
  - Do NOT add mise to Procfile.dev or modify deployment config

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []
  - **Skills Evaluated but Omitted**:
    - `git-master`: Not needed — simple config file + verification

  **Parallelization**:
  - **Can Run In Parallel**: YES
  - **Parallel Group**: Wave 2 (with Tasks 6, 7, 8)
  - **Blocks**: F1-F4
  - **Blocked By**: Task 0

  **References**:

  **Current State References**:
  - `mise.toml` (project root) — Currently: `[tools]\nnode = "24"` (only node)
  - `~/.config/mise/config.toml` — Global config: ruby=3.2.2, node=24, python=3.12, rust=latest
  - `.ruby-version` — Contains `3.2.2`
  - `mise current` output — node 24.14.0, python 3.12.12, ruby 3.2.2, rust 1.93.1
  - `mise tasks ls` — Currently empty (no tasks defined)

  **External References**:
  - Mise docs (tasks): https://mise.jdx.dev/tasks/ — Task definition syntax in TOML
  - Mise docs (tools): https://mise.jdx.dev/configuration.html — Tool version specification

  **Acceptance Criteria**:

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Mise manages all runtimes
    Tool: Bash
    Preconditions: .mise.toml rewritten
    Steps:
      1. Run `mise current`
      2. Assert output contains `ruby` and `3.2.2`
      3. Assert output contains `node` and `24`
      4. Assert output contains `python` and `3.12`
      5. Run `which ruby`
      6. Assert path contains `mise` (not rbenv)
    Expected Result: Mise manages ruby, node, and python
    Failure Indicators: ruby not shown, or which points to rbenv
    Evidence: .sisyphus/evidence/task-9-mise-runtimes.txt

  Scenario: All mise tasks work
    Tool: Bash
    Preconditions: Tasks defined in .mise.toml
    Steps:
      1. Run `mise tasks ls`
      2. Assert output lists: dev, test, test:watch, lint, lint:fix, console, db:reset, db:migrate
      3. Run `mise run test 2>&1 | tail -3`
      4. Assert contains `0 failures`
      5. Run `mise run lint 2>&1 | tail -3`
      6. Assert rubocop output (no crash)
    Expected Result: All 8 tasks defined and executable
    Failure Indicators: Missing tasks, execution errors
    Evidence: .sisyphus/evidence/task-9-mise-tasks.txt

  Scenario: .ruby-version still exists and agrees
    Tool: Bash
    Preconditions: .ruby-version and .mise.toml both specify ruby
    Steps:
      1. Run `cat .ruby-version`
      2. Assert contains `3.2.2`
      3. Run `grep 'ruby' .mise.toml`
      4. Assert contains `3.2.2`
    Expected Result: Both version files agree
    Failure Indicators: Version mismatch or .ruby-version deleted
    Evidence: .sisyphus/evidence/task-9-ruby-version.txt
  ```

  **Commit**: YES
  - Message: `chore(mise): consolidate all runtimes + add dev/test/lint task shortcuts`
  - Files: `.mise.toml`
  - Pre-commit: `mise run test`

---
## Final Verification Wave

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `bundle exec rspec` (all pass?). Run `bin/rubocop` (0 auto-fixable?). Run `npx playwright test --list` (config valid?). Run `mise run test` (task works?). Check all new config files for syntax errors. Verify no application code was modified (`git diff --name-only` should show only config/doc files).
  Output: `RSpec [PASS/FAIL] | Rubocop [PASS/FAIL] | Playwright [PASS/FAIL] | Mise [PASS/FAIL] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high`
  Start from clean state. Verify: `git worktree list` shows correct state. `cat AGENTS.md` has React, orientation, auth, all controllers. `COVERAGE=true bundle exec rspec` generates coverage report. `bundle exec guard list` succeeds. `npx playwright test --list` succeeds. `mise run dev` starts dev server. `mise current` shows ruby + node + python. `.editorconfig` exists with correct settings.
  Output: `Git [N/N checks] | Docs [N/N checks] | Test [N/N checks] | Playwright [N/N checks] | Mise [N/N checks] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff. Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance: no application code changes, no face-recognition modifications, no origin push, no test case writing. Flag any unaccounted file changes.
  Output: `Tasks [N/N compliant] | Must-NOT [N/N clean] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

| Order | Message | Files | Pre-commit |
|-------|---------|-------|------------|
| 1 | `chore(git): commit pending location-autocomplete changes` | staged + modified files | `bundle exec rspec` |
| 2 | `chore(git): remove merged worktrees and gc` | `.gitignore` | — |
| 3 | `fix(gemfile): remove duplicate shoulda-matchers` | `Gemfile`, `Gemfile.lock` | `bundle exec rspec` |
| 4 | `style: auto-fix rubocop offenses` | auto-fixed files | `bin/rubocop` |
| 5 | `chore: add .editorconfig` | `.editorconfig` | — |
| 6 | `docs(agents): full rewrite of AGENTS.md` | `AGENTS.md` | — |
| 7 | `chore(test): add SimpleCov, Guardfile, spec support` | `Gemfile`, `Gemfile.lock`, `.simplecov`, `Guardfile`, `spec/support/*`, `spec/spec_helper.rb` | `bundle exec rspec` |
| 8 | `chore(playwright): add config targeting localhost` | `playwright.config.ts` | `npx playwright test --list` |
| 9 | `chore(mise): consolidate runtimes and add task shortcuts` | `.mise.toml` | `mise run test` |

---

## Success Criteria

### Verification Commands
```bash
git worktree list                          # Expected: 2 entries (main + face-recognition)
git count-objects -v | grep in-pack        # Expected: in-pack > 0
grep '.sisyphus' .gitignore                # Expected: match found
wc -l AGENTS.md                            # Expected: 150-250
grep -c 'React' AGENTS.md                  # Expected: ≥1
grep -c 'orientation' AGENTS.md            # Expected: ≥1
grep -c 'passwordless\|login.code' AGENTS.md  # Expected: ≥1
bundle exec rspec                          # Expected: 140 examples, 0 failures
COVERAGE=true bundle exec rspec            # Expected: generates coverage/index.html
bundle exec guard list                     # Expected: lists guard-rspec
bin/rubocop                                # Expected: 0 auto-fixable offenses
npx playwright test --list                 # Expected: config loads successfully
mise current                               # Expected: shows ruby 3.2.2, node 24.x
mise run test                              # Expected: runs rspec
mise run lint                              # Expected: runs rubocop
cat .editorconfig                          # Expected: valid config exists
cat .sisyphus/boulder.json                 # Expected: file doesn't exist or is reset
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass (140 examples, 0 failures)
- [ ] Zero auto-fixable Rubocop offenses
- [ ] AGENTS.md between 150-250 lines
- [ ] No application code modified
