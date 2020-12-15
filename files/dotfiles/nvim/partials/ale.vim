" Ale
let g:ale_sign_error = '✘'
let g:ale_sign_warning = '⚠'

let g:ale_fix_on_save = 1
let g:ale_completion_autoimport = 1
let g:ale_ruby_sorbet_options = '--no-config --enable-all-experimental-lsp-features --dir=./'

let g:ale_linters_explicit = 1
let g:ale_linters={
\   'python': ['pylint', 'pycodestyle'],
\   'javascript': ['eslint'],
\   'typescript': ['eslint', 'tslint', 'tsserver'],
\   'typescriptreact': ['eslint', 'tslint', 'tsserver'],
\   'html': ['eslint'],
\   'go': ['gofmt', 'staticcheck', 'gobuild', 'gometalinter', 'gosimple', 'golangserver'],
\   'ruby': ['rubocop', 'srb'],
\   'graphql': ['eslint'],
\   'rust': ['cargo', 'rustc', 'rls', 'analyzer'],
\   'proto': ['protoc-gen-lint'],
\}
let g:ale_fixers={
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'javascript': ['prettier', 'importjs'],
\   'typescript': ['prettier', 'importjs', 'tslint'],
\   'typescriptreact': ['prettier', 'importjs', 'tslint'],
\   'html': ['prettier'],
\   'css': ['prettier'],
\   'scss': ['prettier'],
\   'ruby': ['rubocop'],
\   'rust': ['rustfmt'],
\}
