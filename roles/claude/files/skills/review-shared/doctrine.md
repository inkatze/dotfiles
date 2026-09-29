# Review doctrine: resolving planwright's rules

The review skills follow planwright's doctrine documents rather than a copy of
them. Resolve them at the start of a run, before any discovery or validation.

## Locate planwright

planwright's install root is the enabled version's `installPath`, as Claude
Code records it in `~/.claude/plugins/installed_plugins.json`.

```bash
jq -e '.enabledPlugins["planwright@planwright"] == true' ~/.claude/settings.json > /dev/null \
  || { echo "planwright is not enabled in ~/.claude/settings.json" >&2; exit 1; }
jq -er '.plugins["planwright@planwright"] // [] | map(select(.scope == "user")) | last | .installPath // empty' \
  ~/.claude/plugins/installed_plugins.json \
  || { echo "no enabled planwright install recorded in ~/.claude/plugins/installed_plugins.json" >&2; exit 1; }
```

If the record is missing, names no enabled install, or a document does not
resolve, stop and name what is missing; never fall back to a remembered or
inline copy of the rule.

## Resolve the documents

Call the resolver by the literal root the step above printed, one call per
document (a worktree session refuses a call through a shell variable):

```bash
<root>/scripts/resolve-rule-doc.sh validation-rigor
<root>/scripts/resolve-rule-doc.sh discovery-rigor
<root>/scripts/resolve-rule-doc.sh finding-categorization
<root>/scripts/resolve-rule-doc.sh refactor-instinct
```

Each prints a path; read the document there. A skill that never applies
findings (`/code-review`) or never categorizes them (`/peer-review`) still
resolves all four, and uses the last two only where its own text says so.

## What each one governs

- **Issue validation** is validation-rigor's three independent passes per
  finding, including its research triggers and its scoping rule.
- **Solution validation** is validation-rigor's solution section: a targeted
  failing test first, then the wider suite, then edge or manual checks, with
  review angles substituted for a non-testable change.
- **Discovery** is discovery-rigor: its lens checklist, lens-coverage table,
  tool-grounded first pass, fan-out rule and self-critique pass.
- **Categorization** is finding-categorization: four buckets in fixed order
  (Auto-applicable, Agent-resolvable, Needs sign-off, Needs human judgment),
  act-then-review for Needs sign-off, and declined-with-rationale.
- **Refactor flags** follow refactor-instinct's review mode.

## The lens list

The lens list is discovery-rigor's lens checklist, pointed at and never copied.
A backend prompt that needs the list builds it at run time from the resolved
document:

```bash
awk '/^## Lens checklist/{s=1;next} s&&/^[0-9]+\. /{l=1} l&&/^$/{exit} l' "<discovery-rigor path>"
```

Empty output means the document changed shape: stop rather than send a prompt
with no lenses.
