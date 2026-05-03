# Environment Configuration

This system is configured with the following development environment:

## Shell Environment
- **Shell**: Fish shell (`fish`) - A smart and user-friendly command line shell
- **Version Manager**: `mise` (formerly rtx) - Multi-language runtime version manager
- **Terminal Multiplexer**: `tmux` - Terminal session manager

## Running Commands

When you need to execute commands on this system, please use this environment setup:

### Fish Shell
The default shell is Fish. Run commands directly in Fish:
```fish
# Fish shell commands work natively
echo "Hello from Fish"
```

### Mise for Runtime Management
Use `mise` to manage language versions (Node.js, Python, Ruby, etc.):
```fish
mise list              # List installed runtimes
mise current           # Show current versions
mise install node@20   # Install specific versions
```

### Running Mise-Managed Tools
**IMPORTANT**: When running any mise-managed tools, always use Fish shell with mise. The following languages and tools are managed by mise:
- **Languages**: Ruby, Python, Node.js/JavaScript, Go, Rust, Java, Elixir, Erlang
- **Tools**: Terraform, Ansible, and other CLI tools

Examples of running mise-managed tools (use `fish -c "..."` to ensure mise is available):
```bash
# Run Python scripts
fish -c "python script.py"

# Run Ruby scripts
fish -c "ruby script.rb"

# Run Node.js
fish -c "node app.js"
fish -c "npm install"
fish -c "npm run dev"

# Run Go
fish -c "go run main.go"

# Run Rust
fish -c "cargo build"

# Run Terraform
fish -c "terraform plan"

# Run Ansible
fish -c "ansible-playbook playbook.yml"
```

All these commands will automatically use the versions specified in `.mise.toml` or `.tool-versions` files in your project directories.

### Tmux Sessions
Tmux is available for managing terminal sessions:
```fish
tmux ls                # List sessions
tmux attach -t session # Attach to session
tmux new -s session    # Create new session
```

## Git Conventions

When creating git commits:
- Do NOT add `Co-Authored-By: Claude` or any co-author attribution
- Do NOT add the Claude Code generation footer
- Keep commit messages clean and conventional (type: description)
- The user will handle GPG signing

When pushing:
- MUST always specify the remote and branch explicitly: `git push origin branch-name`
- Never use bare `git push` without arguments

## Plan Mode & Implementation

Plans are written with limited context and the codebase may have changed since. When transitioning from a plan to implementation:
- **Plans are directional, not prescriptive**: Treat plans as a guide for intent and scope, not as step-by-step instructions to follow blindly
- **Verify before acting**: Always read the actual code before making changes. Don't assume the plan's description of file contents, function signatures, or structure is accurate
- **Adapt to reality**: If the code doesn't match what the plan expected, adjust your approach to fit the actual state of the codebase rather than forcing the plan's assumptions

## Code & PR Reviews

When reviewing code, features, or addressing PR feedback:
- **Verify issues are real**: Before reporting an issue, confirm it by reading the relevant code and running tests/linters if applicable. Do not report speculative or hypothetical issues, only confirmed ones.
- **Present all issues first**: After analysis, present the complete list of confirmed issues as a numbered summary with brief descriptions.
- **Let the user choose the workflow**: Ask whether they want to review items one by one or discuss the list as a whole (e.g., re-prioritize, dismiss items, group them). Do not assume they want all items addressed at once.
- **Progress tracking**: When going one by one, always show a progress tracker (e.g., `[2/7]`) so the current position and total count are always visible.
- For each item in one-by-one mode: present it, discuss it, and wait for the user's decision before moving to the next.
- This applies to: PR review comments, code review findings, feature review feedback, and any similar review workflow.

### Validation Rigor (Issue Identification)

For any review workflow that flags issues, do at least **three independent validation passes per finding**. Each pass must use a different method or perspective, not the same approach repeated. The goal is to expose blind spots that any single approach misses. If the three passes do not converge on the same conclusion, drop or downgrade the finding.

- **Pass 1: direct reproduction.** When the claim concerns runtime behavior, reproduce it. Write a failing test, run the code, trace through with concrete inputs, or construct the exact failing scenario. Inability to reproduce is a strong signal the issue may not exist.
- **Pass 2: orthogonal angle.** Use a different lens than pass 1. Examples: callers and upstream context, related code paths and side effects, project conventions and sibling implementations, existing test coverage that may already prove the case safe.
- **Pass 3: outside-in angle.** Consult sources outside the diff. `git log` / `git blame` for the why-it-is-the-way-it-is. Repo-wide search for similar patterns. For text or research-based claims (API correctness, spec compliance, deprecated patterns, security claims, library behavior): official docs, the library's own source and tests, the deepwiki MCP for repo facts, GitHub issues, RFCs, web search. Note what was consulted in the finding.

### Validation Rigor (Solutions)

For any fix, validate the solution with at least two independent test angles, three when relevant:

1. **Targeted test.** Write a test that fails on current code for the bug's exact reason. Confirm it fails for the right reason before applying the fix. Apply the fix. Confirm the test now passes.
2. **Wider check.** Run the full project test suite, linters, and type-checkers. Watch for regressions, including in unrelated areas the change could now affect.
3. **Edge / integration / manual.** When relevant: boundary cases (null, empty, max size, concurrency), integration or smoke tests, manual exercise of the user-facing flow.

For non-testable changes (docs, comments, formatting, pure renames, type-only adjustments): substitute review angles. Re-read the diff, read it from the perspective of each caller, and grep the repo for places the change could silently break. Note in the reply why a test was not added.

### Review Workflows
There are four distinct review workflows, each with a corresponding slash command:

1. **Self-review** (`/self-review`): Comprehensive code review of the feature branch against main. Review, validate for false positives, iterate until clean, then push and create a draft PR.
2. **Copilot review** (`/copilot-review`): Address unresolved GitHub Copilot review threads on the current PR. Fetch threads via GraphQL, reproduce each issue when relevant, design our own fix (do not trust Copilot's recommendation), do a second-pass validation, present findings as a table, then implement test-first when applicable, comment, and resolve threads via GraphQL.
3. **Copilot pairing** (`/copilot-pairing`): Same rigor as `/copilot-review`, but loops autonomously: address Copilot's threads, push, re-request review, wait for Copilot's response, repeat until Copilot has no new comments. Hard stop conditions (ambiguity, scope creep, test failure, security-sensitive code, loop detection, iteration cap of 10) hand control back to the human.
4. **Peer review** (`/peer-review`): Address unresolved peer review threads on the current PR. Same validation process as Copilot review, but responses must sound natural, human, and match the user's communication style.

For reviewing **someone else's** PR (not your own), use `/code-review` instead. It checks out the PR, applies the same three-pass validation rigor, and drafts comments for the user to submit manually.

## Writing Style
- Avoid em-dashes in prose unless strictly necessary. Use commas, parentheses, colons, or separate sentences instead.

## Non-obvious Tools

- **`fish`**: Default shell. Use Fish syntax, not bash/zsh (e.g., `set` not `export`).
- **`mise`**: Runtime version manager for all languages (replaces nvm, rbenv, pyenv).
- **`age`**: File encryption tool for metrics snapshots under `specs/metrics-baseline/`.
- **`lefthook`**: Git hooks manager. Pre-commit hooks are defined in `lefthook.yml`.
- **`jq`**: JSON processor. Used by Ansible to merge `settings.json` into `~/.claude/`.
