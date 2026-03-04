# Learnings: docs-freshness-hook

## [2026-03-03] Session ses_34beb5bd0ffe1v91T1Buiu6Z7M — Session Start

### Project Context
- Rails 8.1.2 app, worktree at: /home/pippin/projects/photos-docs-freshness-hook
- bin/setup is a Ruby script using FileUtils and system!
- Zero existing git hooks in the project
- AGENTS.md is ~101 lines, README.md is ~24 lines (both never updated since initial commit)

### Key Conventions
- bin/ scripts use double-quoted strings (Ruby style)
- bin/setup uses system! helper and FileUtils from stdlib
- Hook must be POSIX shell (#!/bin/sh), NOT bash
- Symlink must be relative: ../../bin/pre-commit → .git/hooks/pre-commit
- FileUtils.ln_sf for idempotent symlink creation
- Output style: puts "\n== Section Name ==" matching existing bin/setup pattern

### Critical Technical Decisions
- git diff --cached --name-only: correct command for staged files only
- wc -l: count staged files
- grep -qE: quiet regex match for doc files
- Threshold: 10 files (>= 10 triggers check)
- Doc files checked: AGENTS.md or README.md

## [2026-03-03] Task Completion: bin/pre-commit Hook

### Implementation Summary
Created `/home/pippin/projects/photos/bin/pre-commit` — a POSIX-compliant shell script that enforces documentation freshness for large commits.

### Technical Details
- **Shebang:** `#!/bin/sh` (POSIX, not bash)
- **No bashisms:** Verified absence of `[[ ]]`, arrays, `source`, `local`, process substitution
- **No color codes:** Plain text output only
- **File permissions:** `-rwxrwxr-x` (executable)

### Logic Implementation
1. Count staged files: `git diff --cached --name-only | wc -l`
2. Trim whitespace: `printf '%d' "$staged_count"`
3. Threshold: 10 files (>= 10 triggers check)
4. Doc check: `grep -q "^AGENTS\.md$"` or `grep -q "^README\.md$"`
5. Block behavior: Exit 1 with helpful error message
6. Pass behavior: Exit 0 silently

### QA Results (All 6 Scenarios Pass)
- **Scenario 1:** Block 12 files, no docs → Exit 1 ✓
- **Scenario 2:** Allow 12 files + AGENTS.md → Exit 0 ✓
- **Scenario 3:** Allow 12 files + README.md → Exit 0 ✓
- **Scenario 4:** Allow 5 files, no docs → Exit 0 ✓
- **Scenario 5:** Boundary 10 files, no docs → Exit 1 ✓
- **Scenario 6:** Boundary 9 files, no docs → Exit 0 ✓

### Evidence Location
QA test results saved to: `/home/pippin/projects/photos/.sisyphus/evidence/task-1-qa.txt`

### Key Learnings
- POSIX sh requires careful whitespace handling with `wc -l` output
- `printf '%d'` is the portable way to trim and convert to integer
- `grep -q` with anchors (`^...$`) ensures exact filename matching
- Exit code propagation works correctly in git hooks
- Multi-line heredoc (`cat <<EOF`) is POSIX-compliant for error messages

## [2026-03-03] Task Completion: AGENTS.md Git Hooks Documentation

### Implementation Summary
Added "### Git Hooks" section to AGENTS.md documenting the pre-commit hook behavior.

### Section Details
- **Location:** After "### Database" subsection, before "## Code Style & Conventions"
- **Heading style:** `### Git Hooks` (matches existing subsection format)
- **Content:** 11 lines total (concise, matching existing documentation density)
- **Key points covered:**
  - Threshold: 10+ staged files triggers check
  - Doc files: AGENTS.md or README.md
  - User action: Update docs and stage them
  - Installation: `bin/setup`

### QA Results (All Checks Pass)
- pre-commit mentions: 1 ✓
- "10" mentions: 1 ✓
- AGENTS.md mentions: 3 ✓
- Total lines: 112 (was 101, +11 lines) ✓
- First 5 lines unchanged ✓
- Existing content (Ruby 3.2.2) intact ✓
- Git Hooks section present ✓
- Documentation freshness mentioned ✓

### Evidence Location
QA results saved to: `/home/pippin/projects/photos/.sisyphus/evidence/task-3-qa.txt`

### Key Learnings
- AGENTS.md uses `### heading` format for subsections (3 hashes)
- Operational Commands section groups related commands (Development Server, Testing, Linting, Database, Git Hooks)
- Documentation style is concise with bullet points and code blocks
- Placement between Database and Code Style sections is logical for development workflow concerns

## Task 2: Git Hooks Installation in bin/setup

### Key Learnings

1. **Worktree Git Directory Structure**
   - In a git worktree, `.git` is a FILE (not a directory) that points to the actual git directory
   - Use `git rev-parse --git-dir` to get the actual git directory path
   - For worktrees: actual git dir is at `.git/worktrees/{worktree-name}/`

2. **Relative Path Calculation**
   - Use `Pathname.relative_path_from()` for cross-platform relative path calculation
   - This handles complex directory structures (like worktrees) correctly
   - Requires `require "pathname"` at the top of the script

3. **FileUtils.ln_sf Idempotency**
   - `FileUtils.ln_sf` (symbolic link + force) is idempotent
   - Can safely run multiple times without errors
   - The `-f` flag overwrites existing symlinks

4. **bin/setup Pattern**
   - All code runs inside `FileUtils.chdir APP_ROOT do` block
   - Section headers use format: `puts "\n== Section Name =="`
   - Sections should be placed logically (dependencies → hooks → database → cleanup)

5. **Implementation Details**
   - Added `require "pathname"` on line 3
   - Git hooks section placed between "Installing dependencies" and "Preparing database"
   - Uses `git rev-parse --git-dir` to handle both normal repos and worktrees
   - Calculates relative path dynamically for portability

### Code Pattern
```ruby
puts "\n== Installing git hooks =="
git_dir = `git rev-parse --git-dir`.strip
hooks_dir = File.join(git_dir, "hooks")
FileUtils.mkdir_p hooks_dir
hooks_abs = File.expand_path(hooks_dir)
bin_pre_commit_abs = File.expand_path("bin/pre-commit")
rel_path = Pathname.new(bin_pre_commit_abs).relative_path_from(Pathname.new(hooks_abs)).to_s
FileUtils.ln_sf rel_path, File.join(hooks_dir, "pre-commit")
```

### Testing
- Verified symlink creation with `ruby bin/setup --skip-server`
- Verified idempotency by running twice
- Verified relative path with `readlink`
- Evidence saved to `/home/pippin/projects/photos/.sisyphus/evidence/task-2-qa.txt`
