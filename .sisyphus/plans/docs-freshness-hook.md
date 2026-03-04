# Docs Freshness Pre-Commit Hook

## TL;DR

> **Quick Summary**: Add a local pre-commit git hook that blocks commits touching 10+ files unless AGENTS.md or README.md is also staged. Enforces documentation freshness on large changes.
> 
> **Deliverables**:
> - `bin/pre-commit` — POSIX shell hook script
> - Updated `bin/setup` — Ruby symlink installer
> - Updated `AGENTS.md` — Documents the hook's existence and behavior
> 
> **Estimated Effort**: Quick
> **Parallel Execution**: YES — 2 waves
> **Critical Path**: Task 1 → Tasks 2 & 3 (parallel)

---

## Context

### Original Request
User wants a hook that runs on every big change to ensure documentation (AGENTS.md and README.md) stays up-to-date. After discussion, this was refined to a local pre-commit hook with a 10-file threshold.

### Interview Summary
**Key Discussions**:
- **Trigger**: Any commit with 10+ staged files (not structural detection)
- **Check**: Simple presence — are AGENTS.md or README.md among the staged files?
- **Enforcement**: Hard block (exit 1), no custom escape hatch
- **Distribution**: Hook script lives in `bin/` (version-controlled), symlinked by `bin/setup`
- **No CI backup**: Local hook is the only enforcement mechanism
- **No new dependencies**: Pure POSIX shell script + Ruby addition to bin/setup

**Research Findings**:
- Project has zero existing git hooks — this is the first
- All current automation is CI-based (GitHub Actions)
- `bin/setup` is a Ruby script using `system!` and `FileUtils`
- Both AGENTS.md and README.md have never been updated since initial commit

### Metis Review
**Identified Gaps** (addressed):
- **`--amend` and merge commits**: Hook should handle these the same as regular commits (count staged files regardless of commit type)
- **Renamed/deleted files**: `git diff --cached --name-only` includes renames and deletions — these count toward the 10-file threshold, which is correct
- **Existing hook collision**: Since there are zero existing hooks, no collision risk. But `bin/setup` should check before overwriting.
- **Symlink path type**: Use relative symlink so it works regardless of where the repo is cloned
- **bin/setup is Ruby, hook is POSIX shell**: Plan must clearly separate the two languages
- **Edge cases**: Empty/first commit, partial staging, no .git directory, file-mode-only changes

---

## Work Objectives

### Core Objective
Enforce a "docs or it didn't happen" policy: any commit touching 10+ files must also include changes to AGENTS.md or README.md.

### Concrete Deliverables
- `bin/pre-commit` — Executable POSIX shell script
- Updated `bin/setup` — Adds hook symlink installation step
- Updated `AGENTS.md` — Documents the hook under a new section

### Definition of Done
- [x] `git commit` with 10+ staged files and no doc changes → blocked with helpful message
- [x] `git commit` with 10+ staged files including AGENTS.md → passes
- [x] `git commit` with 10+ staged files including README.md → passes
- [x] `git commit` with <10 staged files and no doc changes → passes silently
- [x] `bin/setup --skip-server` installs the hook symlink
- [x] AGENTS.md documents the hook behavior and threshold

### Must Have
- POSIX-compliant shell (no bashisms) — works on macOS and Linux
- Exit 1 on violation with a clear, helpful error message explaining what to do
- Silent pass on non-triggering commits (no noise)
- Hook counts only staged files (not working tree changes)
- `bin/setup` creates symlink idempotently (safe to run multiple times)

### Must NOT Have (Guardrails)
- **No structural change detection** — just file count, not file type analysis
- **No content analysis** — don't inspect what changed in docs, just that they're staged
- **No new gems or npm packages** — pure shell + Ruby only
- **No CI workflow changes** — local hook only, leave `.github/workflows/ci.yml` alone
- **No custom bypass mechanism** — no env var override, no config file to disable
- **No color codes in output** — keep message plain text for compatibility
- **No changes to existing bin/ scripts** other than `bin/setup`

---

## Verification Strategy

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (RSpec)
- **Automated tests**: None — this is a shell script hook; verification is via QA scenarios
- **Framework**: N/A

### QA Policy
Every task includes agent-executed QA scenarios using tmux/bash to test the hook behavior directly.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Hook script**: Use Bash — create temp git repo, stage files, attempt commits, verify exit codes
- **bin/setup**: Use Bash — run setup, verify symlink exists and points correctly
- **AGENTS.md**: Use Bash — grep for expected documentation content

---

## Execution Strategy

### Parallel Execution Waves

```
Wave 1 (Start Immediately — the hook script):
└── Task 1: Create bin/pre-commit hook script [quick]

Wave 2 (After Wave 1 — installation + docs, PARALLEL):
├── Task 2: Update bin/setup to install hook symlink [quick]
└── Task 3: Update AGENTS.md to document the hook [quick]

Wave FINAL (After ALL tasks — independent review):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real QA - end-to-end hook testing (unspecified-high)
└── Task F4: Scope fidelity check (deep)

Critical Path: Task 1 → Task 2/3 → Final
Max Concurrent: 2 (Wave 2)
```

### Dependency Matrix

| Task | Depends On | Blocks | Wave |
|------|-----------|--------|------|
| 1    | —         | 2, 3   | 1    |
| 2    | 1         | Final  | 2    |
| 3    | 1         | Final  | 2    |

### Agent Dispatch Summary

- **Wave 1**: 1 task — T1 → `quick`
- **Wave 2**: 2 tasks — T2 → `quick`, T3 → `quick`
- **Final**: 4 tasks — F1 → `oracle`, F2 → `unspecified-high`, F3 → `unspecified-high`, F4 → `deep`

---

## TODOs

- [x] 1. Create `bin/pre-commit` hook script

  **What to do**:
  - Create `bin/pre-commit` as a POSIX-compliant shell script (shebang: `#!/bin/sh`)
  - Count staged files using `git diff --cached --name-only | wc -l`
  - If count >= 10, check if `AGENTS.md` or `README.md` appears in `git diff --cached --name-only`
  - If neither doc file is staged: print a clear multi-line error message explaining the policy, what triggered it (N files staged), and what to do (stage AGENTS.md or README.md with updates), then `exit 1`
  - If either doc file IS staged, or count < 10: `exit 0` silently (no output)
  - Make the file executable (`chmod +x bin/pre-commit`)
  - Edge cases to handle:
    - Works correctly on `--amend` commits (git still runs pre-commit hooks)
    - Works correctly on merge commits
    - File-mode-only changes count toward the threshold (this is fine — `git diff --cached --name-only` includes them)
    - Deleted and renamed files count toward the threshold (correct behavior)

  **Must NOT do**:
  - No bashisms (`[[ ]]`, arrays, `source`, `local` in non-function context)
  - No color codes or ANSI escapes in output
  - No env var checks for bypass
  - No content analysis of what changed in docs
  - Do not inspect file types or categories

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Single file creation, straightforward shell scripting
  - **Skills**: `[]`
    - No specialized skills needed for a POSIX shell script

  **Parallelization**:
  - **Can Run In Parallel**: NO (Wave 1 — foundation)
  - **Parallel Group**: Wave 1 (sole task)
  - **Blocks**: Tasks 2, 3
  - **Blocked By**: None (can start immediately)

  **References**:

  **Pattern References**:
  - `bin/rubocop` — Example of an executable script in bin/ (check shebang and permissions pattern)
  - `bin/brakeman` — Another bin/ script to match style for header comments

  **API/Type References**:
  - `git diff --cached --name-only` — Lists staged file paths, one per line
  - `wc -l` — Count lines (files)
  - `grep -qE` — Quiet regex match for checking AGENTS.md or README.md in output

  **External References**:
  - `man githooks` — pre-commit hook specification: runs before commit message, exit 0 = proceed, non-zero = abort

  **WHY Each Reference Matters**:
  - `bin/rubocop` and `bin/brakeman`: Match the project's convention for bin/ scripts (shebang style, any header comments)
  - `git diff --cached --name-only`: This is the correct command — `--cached` means staged files only, `--name-only` gives paths without diff content
  - The hook must use POSIX shell to work on both macOS (default sh = zsh-compatible POSIX) and Linux (dash/bash)

  **Acceptance Criteria**:
  - [x] File exists at `bin/pre-commit`
  - [x] File is executable (`test -x bin/pre-commit`)
  - [x] Shebang is `#!/bin/sh` (not `#!/bin/bash`)
  - [x] No bashisms: `shellcheck bin/pre-commit` passes (or manual review for POSIX compliance)

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: Block commit with 10+ files and no docs
    Tool: Bash
    Preconditions: Create temp git repo, init, create bin/pre-commit symlink or copy
    Steps:
      1. mkdir /tmp/test-hook-$$ && cd /tmp/test-hook-$$
      2. git init && git commit --allow-empty -m 'init'
      3. cp /home/pippin/projects/photos/bin/pre-commit .git/hooks/pre-commit
      4. touch file{01..12}.txt && git add file{01..12}.txt
      5. git commit -m 'test' 2>&1
    Expected Result: Exit code 1, stderr/stdout contains message about updating documentation
    Failure Indicators: Exit code 0, or no error message, or cryptic error instead of helpful message
    Evidence: .sisyphus/evidence/task-1-block-no-docs.txt

  Scenario: Allow commit with 10+ files when AGENTS.md is staged
    Tool: Bash
    Preconditions: Same temp repo from previous scenario (or fresh one)
    Steps:
      1. Create temp git repo with hook installed
      2. touch file{01..12}.txt AGENTS.md && git add file{01..12}.txt AGENTS.md
      3. git commit -m 'test with agents' 2>&1
    Expected Result: Exit code 0, no output from hook
    Failure Indicators: Exit code 1, or any warning/error output
    Evidence: .sisyphus/evidence/task-1-allow-agents-md.txt

  Scenario: Allow commit with 10+ files when README.md is staged
    Tool: Bash
    Preconditions: Fresh temp repo with hook installed
    Steps:
      1. Create temp git repo with hook installed
      2. touch file{01..12}.txt README.md && git add file{01..12}.txt README.md
      3. git commit -m 'test with readme' 2>&1
    Expected Result: Exit code 0, no output from hook
    Failure Indicators: Exit code 1, or any warning/error output
    Evidence: .sisyphus/evidence/task-1-allow-readme-md.txt

  Scenario: Allow small commit without docs (below threshold)
    Tool: Bash
    Preconditions: Fresh temp repo with hook installed
    Steps:
      1. Create temp git repo with hook installed
      2. touch file{1..5}.txt && git add file{1..5}.txt
      3. git commit -m 'small change' 2>&1
    Expected Result: Exit code 0, no output from hook
    Failure Indicators: Exit code 1, or any output at all
    Evidence: .sisyphus/evidence/task-1-allow-small-commit.txt

  Scenario: Boundary — exactly 10 files, no docs
    Tool: Bash
    Preconditions: Fresh temp repo with hook installed
    Steps:
      1. Create temp git repo with hook installed
      2. touch file{01..10}.txt && git add file{01..10}.txt
      3. git commit -m 'boundary test' 2>&1
    Expected Result: Exit code 1, blocked (10 >= 10 threshold)
    Failure Indicators: Exit code 0 (off-by-one error)
    Evidence: .sisyphus/evidence/task-1-boundary-ten.txt

  Scenario: Boundary — exactly 9 files, no docs
    Tool: Bash
    Preconditions: Fresh temp repo with hook installed
    Steps:
      1. Create temp git repo with hook installed
      2. touch file{1..9}.txt && git add file{1..9}.txt
      3. git commit -m 'just under' 2>&1
    Expected Result: Exit code 0, passes silently (9 < 10)
    Failure Indicators: Exit code 1 (off-by-one error)
    Evidence: .sisyphus/evidence/task-1-boundary-nine.txt
  ```

  **Evidence to Capture:**
  - [x] Each evidence file named: task-1-{scenario-slug}.txt
  - [x] Terminal output for each scenario including exit code

  **Commit**: YES (groups with Tasks 2, 3)
  - Message: `feat(hooks): add pre-commit docs-freshness check`
  - Files: `bin/pre-commit`
  - Pre-commit: N/A (this IS the pre-commit hook)

- [x] 2. Update `bin/setup` to install hook via symlink

  **What to do**:
  - Add a new section to `bin/setup` (Ruby script) that creates a symlink from `.git/hooks/pre-commit` → `../../bin/pre-commit`
  - Place the new section AFTER "Installing dependencies" and BEFORE "Preparing database" — hook installation is a dev environment concern
  - Use `FileUtils.ln_sf` for idempotent symlink creation (safe to run multiple times)
  - Print a status message: `puts "\n== Installing git hooks =="` to match existing output style
  - Ensure the `.git/hooks` directory exists before creating the symlink (it should, but defensive coding)
  - Use relative path for symlink so it works regardless of where the repo is cloned

  **Must NOT do**:
  - Do not modify any other section of `bin/setup`
  - Do not add conditional logic ("only install if not exists") — `ln_sf` handles this
  - Do not check if git is installed or if .git exists — `bin/setup` already assumes a git repo
  - Do not add any gems or dependencies

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Adding ~4 lines to an existing Ruby script
  - **Skills**: `[]`
    - No specialized skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 3)
  - **Parallel Group**: Wave 2 (with Task 3)
  - **Blocks**: Final verification
  - **Blocked By**: Task 1 (hook script must exist before we symlink to it)

  **References**:

  **Pattern References**:
  - `bin/setup:15-16` — Existing `puts` + `system!` pattern for section headers. Match this style exactly: `puts "\n== Section Name =="` followed by the action
  - `bin/setup:10` — `FileUtils.chdir APP_ROOT do` block — all code must be inside this block
  - `bin/setup:2` — `require "fileutils"` — `FileUtils` is already imported, no need to add

  **API/Type References**:
  - `FileUtils.mkdir_p` — Creates directory and parents, no-op if exists
  - `FileUtils.ln_sf(src, dest)` — Creates symlink, overwrites if exists (`_sf` = symbolic + force)

  **WHY Each Reference Matters**:
  - `bin/setup` lines 15-16: The hook installation section must look identical in style to "Installing dependencies" and "Preparing database" sections
  - `FileUtils.ln_sf`: This is the key — `_sf` means it won't error if the symlink already exists, making `bin/setup` idempotent

  **Acceptance Criteria**:
  - [x] `bin/setup` contains hook installation section
  - [x] Running `bin/setup --skip-server` creates symlink at `.git/hooks/pre-commit`
  - [x] Running `bin/setup --skip-server` twice does not error (idempotent)
  - [x] Symlink uses relative path: `readlink .git/hooks/pre-commit` → `../../bin/pre-commit`

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: bin/setup creates hook symlink
    Tool: Bash
    Preconditions: Remove existing .git/hooks/pre-commit if present
    Steps:
      1. rm -f .git/hooks/pre-commit
      2. ruby bin/setup --skip-server 2>&1 (run from project root)
      3. test -L .git/hooks/pre-commit && echo 'SYMLINK EXISTS' || echo 'MISSING'
      4. readlink .git/hooks/pre-commit
    Expected Result: Symlink exists, readlink shows '../../bin/pre-commit'
    Failure Indicators: No symlink, absolute path, or error during setup
    Evidence: .sisyphus/evidence/task-2-setup-creates-symlink.txt

  Scenario: bin/setup is idempotent (run twice)
    Tool: Bash
    Preconditions: Hook symlink may or may not exist
    Steps:
      1. ruby bin/setup --skip-server 2>&1
      2. ruby bin/setup --skip-server 2>&1
      3. test -L .git/hooks/pre-commit && echo 'STILL EXISTS'
    Expected Result: Both runs succeed with exit 0, symlink still present after second run
    Failure Indicators: Error on second run, symlink missing, or file instead of symlink
    Evidence: .sisyphus/evidence/task-2-setup-idempotent.txt
  ```

  **Evidence to Capture:**
  - [x] Each evidence file named: task-2-{scenario-slug}.txt
  - [x] Terminal output including readlink result

  **Commit**: YES (groups with Tasks 1, 3)
  - Message: `feat(hooks): add pre-commit docs-freshness check`
  - Files: `bin/setup`
  - Pre-commit: The hook will run — 3-file commit (<10 threshold) passes silently

- [x] 3. Update AGENTS.md to document the hook

  **What to do**:
  - Add a new section to AGENTS.md documenting the pre-commit hook
  - Place it logically — after "Operational Commands" or near "General Guidelines" since it's a development workflow concern
  - Document: what the hook does, when it triggers (10+ files), what it checks (AGENTS.md or README.md staged), what to do when blocked (update the relevant doc file and stage it)
  - Keep it concise — 5-10 lines maximum, matching the existing documentation density
  - Use the existing markdown style (### headings, bullet lists, code blocks for commands)

  **Must NOT do**:
  - Do not rewrite or restructure existing AGENTS.md sections
  - Do not add verbose explanations — match existing conciseness
  - Do not document the implementation details (shell commands used internally)
  - Do not mention --no-verify or any bypass methods

  **Recommended Agent Profile**:
  - **Category**: `quick`
    - Reason: Adding a small documentation section to an existing file
  - **Skills**: `[]`
    - No specialized skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 2)
  - **Parallel Group**: Wave 2 (with Task 2)
  - **Blocks**: Final verification
  - **Blocked By**: Task 1 (need to know exact hook behavior to document it accurately)

  **References**:

  **Pattern References**:
  - `AGENTS.md:19-34` — "Operational Commands" section — match heading level, formatting, and density
  - `AGENTS.md:36-46` — "Code Style & Conventions" section — reference for how conventions are documented

  **WHY Each Reference Matters**:
  - The new section must look like it was written by the same person who wrote the existing AGENTS.md — same heading depth, same bullet style, same level of detail

  **Acceptance Criteria**:
  - [x] AGENTS.md contains a section about the pre-commit hook
  - [x] Section explains: what triggers it (10+ files), what it checks (AGENTS.md or README.md), what to do when blocked
  - [x] Section is 5-15 lines (concise, matches existing style)
  - [x] No existing content in AGENTS.md was modified or removed

  **QA Scenarios (MANDATORY):**

  ```
  Scenario: AGENTS.md documents the hook
    Tool: Bash
    Preconditions: AGENTS.md has been updated
    Steps:
      1. grep -c 'pre-commit' AGENTS.md
      2. grep -c '10' AGENTS.md (or however threshold is referenced)
      3. grep -c 'AGENTS.md' AGENTS.md (self-reference about what to update)
    Expected Result: All grep commands return >= 1 match
    Failure Indicators: Any grep returns 0 (missing documentation)
    Evidence: .sisyphus/evidence/task-3-agents-md-documented.txt

  Scenario: Existing AGENTS.md content unchanged
    Tool: Bash
    Preconditions: Know the original line count (101 lines)
    Steps:
      1. wc -l AGENTS.md (should be > 101, not less)
      2. head -5 AGENTS.md (first 5 lines should be unchanged)
      3. grep -c 'Ruby 3.2.2' AGENTS.md (existing content intact)
    Expected Result: Line count increased, existing content preserved
    Failure Indicators: Line count decreased, existing content missing or modified
    Evidence: .sisyphus/evidence/task-3-agents-md-preserved.txt
  ```

  **Evidence to Capture:**
  - [x] Each evidence file named: task-3-{scenario-slug}.txt
  - [x] grep output confirming documentation presence

  **Commit**: YES (groups with Tasks 1, 2)
  - Message: `feat(hooks): add pre-commit docs-freshness check`
  - Files: `AGENTS.md`
  - Pre-commit: The hook will run — 3-file commit (<10 threshold) passes silently

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Rejection → fix → re-run.

- [x] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [x] F2. **Code Quality Review** — `unspecified-high`
  Review `bin/pre-commit` for: POSIX compliance (no bashisms like `[[ ]]`, `source`, arrays), proper quoting, correct exit codes. Review `bin/setup` changes for: Ruby style consistency with existing code, idempotent symlink creation. Check for: commented-out code, debug prints, unnecessary complexity.
  Output: `POSIX [PASS/FAIL] | Ruby Style [PASS/FAIL] | Clean [YES/NO] | VERDICT`

- [x] F3. **Real QA — End-to-End Hook Testing** — `unspecified-high`
  Start from clean state. Create a temporary git repo, install the hook, and run EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test the full flow: `bin/setup` installs hook → hook blocks/passes correctly for each scenario. Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Edge Cases [N tested] | VERDICT`

- [x] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance: no CI changes, no new dependencies, no structural detection, no color codes. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Creep [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Commit 1** (after Wave 2): `feat(hooks): add pre-commit docs-freshness check` — `bin/pre-commit`, `bin/setup`, `AGENTS.md`
  - Pre-commit: The hook itself will run — but since it's a 3-file commit (<10 threshold), it will pass silently. This is a nice self-test.

---

## Success Criteria

### Verification Commands
```bash
# Hook exists and is executable
test -x bin/pre-commit && echo "PASS" || echo "FAIL"

# Symlink installed correctly (after bin/setup)
test -L .git/hooks/pre-commit && echo "PASS" || echo "FAIL"

# Symlink points to the right place
readlink .git/hooks/pre-commit  # Expected: ../../bin/pre-commit

# AGENTS.md documents the hook
grep -q "pre-commit" AGENTS.md && echo "PASS" || echo "FAIL"
```

### Final Checklist
- [x] All "Must Have" present
- [x] All "Must NOT Have" absent
- [x] Hook blocks 10+ file commits without docs
- [x] Hook passes 10+ file commits with docs
- [x] Hook is silent on small commits
- [x] bin/setup installs hook idempotently
- [x] AGENTS.md documents hook behavior
