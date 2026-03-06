function cursor-rules --description 'Symlink shared CLAUDE.md into the current project for Cursor CLI'
    set -l rules_source "$HOME/dev/dotfiles/roles/osx/files/CLAUDE.md"

    if not test -f "$rules_source"
        echo "Error: source CLAUDE.md not found at $rules_source"
        return 1
    end

    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo "Error: not inside a git repository"
        return 1
    end

    set -l repo_root (git rev-parse --show-toplevel)
    set -l target "$repo_root/CLAUDE.md"

    if test -L "$target"
        echo "Already linked: CLAUDE.md"
        return 0
    end

    if test -e "$target"
        echo "Error: CLAUDE.md already exists and is not a symlink"
        return 1
    end

    ln -s "$rules_source" "$target"
    echo "Linked: CLAUDE.md -> $rules_source"
end
