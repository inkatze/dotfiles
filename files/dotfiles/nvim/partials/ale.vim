" Ale
let g:ale_sign_error = '✘'
let g:ale_sign_warning = '⚠'

let g:ale_fix_on_save = 1
let g:ale_completion_tsserver_autoimport = 1
let g:ale_ruby_sorbet_options = '--no-config --enable-all-experimental-lsp-features'

let g:ale_linters_explicit = 1
let g:ale_linters={
\   'python': ['pylint', 'pycodestyle'],
\   'javascript': ['eslint'],
\   'typescript': ['eslint'],
\   'html': ['eslint'],
\   'go': ['gofmt', 'staticcheck', 'gobuild', 'gometalinter', 'gosimple', 'golangserver'],
\   'ruby': ['rubocop', 'sorbet'],
\   'graphql': ['eslint']
\}
let g:ale_fixers={
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'javascript': ['prettier'],
\   'typescript': ['prettier'],
\   'html': ['prettier'],
\   'css': ['prettier'],
\   'scss': ['prettier'],
\   'ruby': ['rubocop', 'sorbet'],
\}
