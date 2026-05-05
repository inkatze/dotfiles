#!/usr/bin/env bash
# Surface project-shipped quality tooling as SessionStart additionalContext.
# Wired from ~/.claude/settings.json.
#
# Purpose: Discovery Rigor and Refactor Instinct in CLAUDE.md want the agent
# to ground decisions in what the project actually runs (linters, formatters,
# type checkers, etc.) rather than vibes. This hook does the cwd scan once at
# session start so the agent sees a short list without having to grep around.
#
# Output: a small JSON blob with `additionalContext` if any tooling is
# detected, or no output (silent) if nothing is found. Uses bash 3.2 +
# `set -u` to stay compatible with the macOS default bash.

set -u

cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
[ -d "$cwd" ] || exit 0
cd "$cwd" 2>/dev/null || exit 0

names=()
add() { names+=("$1"); }

# Hook managers / multi-tool runners
if [ -f lefthook.yml ] || [ -f .lefthook.yml ] || [ -f lefthook.yaml ]; then
    add "lefthook (run pre-commit hooks: \`lefthook run pre-commit\`)"
fi
if [ -f .pre-commit-config.yaml ]; then
    add "pre-commit (\`pre-commit run --all-files\`)"
fi
if [ -f Makefile ] || [ -f makefile ] || [ -f GNUmakefile ]; then
    add "Makefile (\`make\` targets; try \`make help\`)"
fi
if [ -f mise.toml ] || [ -f .mise.toml ] || [ -f .tool-versions ]; then
    add "mise tasks (\`mise tasks\` to list)"
fi

# Ruby
if [ -f .rubocop.yml ] || [ -f .rubocop.yaml ]; then
    add "rubocop (\`bundle exec rubocop\`)"
fi
if [ -f sorbet/config ]; then
    add "sorbet (\`bundle exec srb tc\`)"
fi
if [ -f .standard.yml ]; then
    add "standardrb (\`bundle exec standardrb\`)"
fi

# Python
if [ -f pyproject.toml ]; then
    py_tools=""
    grep -q '\[tool\.ruff' pyproject.toml 2>/dev/null && py_tools="${py_tools}ruff "
    grep -q '\[tool\.mypy' pyproject.toml 2>/dev/null && py_tools="${py_tools}mypy "
    grep -q '\[tool\.pyright' pyproject.toml 2>/dev/null && py_tools="${py_tools}pyright "
    grep -q '\[tool\.black' pyproject.toml 2>/dev/null && py_tools="${py_tools}black "
    grep -q '\[tool\.isort' pyproject.toml 2>/dev/null && py_tools="${py_tools}isort "
    if [ -n "$py_tools" ]; then
        add "Python (pyproject.toml: ${py_tools% })"
    else
        add "Python (pyproject.toml present; check for ruff/mypy/black/etc.)"
    fi
fi
[ -f mypy.ini ] || [ -f .mypy.ini ] && add "mypy (\`mypy .\`)"
[ -f pyrightconfig.json ] && add "pyright (\`pyright\`)"
[ -f .ruff.toml ] || [ -f ruff.toml ] && add "ruff (\`ruff check .\`)"

# TypeScript / JavaScript
[ -f tsconfig.json ] && add "tsc (\`tsc --noEmit\`)"
if [ -f .eslintrc.json ] || [ -f .eslintrc.js ] || [ -f .eslintrc.cjs ] || [ -f .eslintrc.yml ] || [ -f eslint.config.js ] || [ -f eslint.config.mjs ] || [ -f eslint.config.cjs ]; then
    add "eslint (\`eslint .\`)"
fi
[ -f biome.json ] || [ -f biome.jsonc ] && add "biome (\`biome check .\`)"
if [ -f .prettierrc ] || [ -f .prettierrc.json ] || [ -f .prettierrc.js ] || [ -f .prettierrc.yml ] || [ -f prettier.config.js ] || [ -f prettier.config.cjs ]; then
    add "prettier (\`prettier --check .\`)"
fi
[ -f knip.json ] || [ -f .knip.json ] || [ -f knip.config.ts ] && add "knip (dead-code: \`knip\`)"
if [ -f package.json ]; then
    add "package.json scripts (\`npm run\` or \`pnpm run\` to list lint/test/typecheck/format)"
fi

# Go
if [ -f go.mod ]; then
    add "go (\`go vet ./...\`, \`gofmt -l .\`)"
    [ -f .golangci.yml ] || [ -f .golangci.yaml ] && add "golangci-lint (\`golangci-lint run\`)"
fi

# Rust
if [ -f Cargo.toml ]; then
    add "cargo (\`cargo clippy --all-targets\`, \`cargo fmt --check\`)"
fi

# Elixir
if [ -f mix.exs ]; then
    add "Elixir mix (\`mix format --check-formatted\`; check mix.exs for credo/dialyxir)"
fi

# Erlang
[ -f rebar.config ] && add "rebar3 (\`rebar3 dialyzer\`)"

# Java / Kotlin
[ -f build.gradle ] || [ -f build.gradle.kts ] || [ -f pom.xml ] && add "JVM build (\`./gradlew check\` or \`mvn verify\`)"

# Shell
[ -f .shellcheckrc ] && add "shellcheck (\`shellcheck **/*.sh\`)"

# YAML / Ansible (this dotfiles repo uses these)
[ -f .yamllint ] || [ -f .yamllint.yml ] || [ -f .yamllint.yaml ] && add "yamllint (\`yamllint .\`)"
[ -f .ansible-lint ] || [ -f .ansible-lint.yml ] || [ -f ansible-lint.yml ] && add "ansible-lint (\`ansible-lint\`)"

# Security / supply chain
[ -f .gitleaks.toml ] && add "gitleaks (\`gitleaks detect\`)"
[ -f .trivyignore ] && add "trivy (\`trivy fs .\`)"

# CI workflows (presence often implies more checks the agent should respect)
ci_count=0
for f in .github/workflows/*.yml .github/workflows/*.yaml; do
    [ -f "$f" ] && ci_count=$((ci_count + 1))
done
[ $ci_count -gt 0 ] && add ".github/workflows ($ci_count file(s); inspect for additional checks)"
[ -f .gitlab-ci.yml ] && add ".gitlab-ci.yml"
[ -f .circleci/config.yml ] && add ".circleci/config.yml"

# If nothing detected, stay silent.
total=${#names[@]}
[ $total -eq 0 ] && exit 0

# Build markdown summary.
summary="## Project tooling (auto-detected)

Use these for tool-grounded discovery and refactor decisions (per CLAUDE.md \`Discovery Rigor\` and \`Refactor Instinct\`). Tool output is grounded; vibes are not.
"
for ((i=0; i<total; i++)); do
    summary="${summary}
- ${names[$i]}"
done

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' \
    "$(printf '%s' "$summary" | jq -Rs .)"

exit 0
