" Ale
let g:ale_sign_error = '✘'
let g:ale_sign_warning = '⚠'

let g:ale_fix_on_save = 1
let g:ale_completion_autoimport = 1
let g:ale_ruby_sorbet_options = '--no-config --enable-all-experimental-lsp-features'
let g:ale_ruby_rubocop_executable = 'bundle'
let g:ale_ruby_sorbet_executable = 'bundle'

let g:ale_linters_explicit = 1
let g:ale_linters={
\   'python': ['pylint', 'pycodestyle'],
\   'javascript': ['eslint'],
\   'typescript': ['eslint', 'tslint', 'tsserver'],
\   'html': ['eslint'],
\   'go': ['gofmt', 'staticcheck', 'gobuild', 'gometalinter', 'gosimple', 'golangserver'],
\   'ruby': ['rubocop', 'solargraph'],
\   'graphql': ['eslint'],
\   'rust': ['cargo', 'rustc', 'rls', 'analyzer'],
\   'proto': ['protoc-gen-lint'],
\}
let g:ale_fixers={
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'javascript': ['prettier', 'importjs'],
\   'typescript': ['prettier', 'importjs', 'tslint'],
\   'html': ['prettier'],
\   'css': ['prettier'],
\   'scss': ['prettier'],
\   'ruby': ['rubocop'],
\   'rust': ['rustfmt'],
\}
