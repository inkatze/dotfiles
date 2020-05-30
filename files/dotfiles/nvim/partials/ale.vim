" Ale
let g:ale_sign_error = '✘'
let g:ale_sign_warning = '⚠'
highlight ALEErrorSign ctermbg=NONE ctermfg=red
highlight ALEWarningSign ctermbg=NONE ctermfg=yellow

let g:ale_linters_explicit=1
let g:ale_ruby_rubocop_executable = $RBENV_ROOT.'/shims/bundle'
let g:ale_linters={
\   'python': ['pylint', 'pycodestyle'],
\   'javascript': ['eslint'],
\   'jsx': ['eslint'],
\   'html': ['eslint'],
\   'typescript': ['eslint'],
\   'go': ['gofmt', 'staticcheck', 'gobuild', 'gometalinter', 'gosimple', 'golangserver'],
\   'ruby': ['standardrb', 'rubocop', 'sorbet'],
\}
let g:ale_fixers={
\   '*': ['remove_trailing_lines', 'trim_whitespace'],
\   'javascript': ['prettier'],
\   'jsx': ['prettier'],
\   'html': ['prettier'],
\   'css': ['prettier'],
\   'typescript': ['prettier'],
\   'ruby': ['rubocop'],
\}
let g:ale_fix_on_save=1
