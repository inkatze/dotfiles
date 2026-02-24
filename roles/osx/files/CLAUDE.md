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
- **Verify before acting**: Always read the actual code before making changes — don't assume the plan's description of file contents, function signatures, or structure is accurate
- **Adapt to reality**: If the code doesn't match what the plan expected, adjust your approach to fit the actual state of the codebase rather than forcing the plan's assumptions

## Code & PR Reviews

When reviewing code, features, or addressing PR feedback:
- When presenting findings or acting on feedback, go through items **one by one** interactively
- Analysing everything upfront is fine
- For each item: present it, discuss it, and wait for the user's decision before moving to the next
- This applies to: PR review comments, code review findings, feature review feedback, and any similar review workflow

## Important Notes
- Fish shell uses different syntax than bash/zsh (e.g., `set` instead of `export` for variables)
- `mise` handles all runtime version management (replaces nvm, rbenv, pyenv, etc.)
- Configuration files are managed through Ansible and symlinked from this dotfiles repository
