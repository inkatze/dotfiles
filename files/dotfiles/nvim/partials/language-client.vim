" LanguageClient-neovim
set runtimepath+=$HOME/.local/share/nvim/site/pack/plugins/start/LanguageClient-neovim
set hidden

" bindings ->>1
function  LanguageClientMappers()
  nnoremap <F5> :call LanguageClient_contextMenu()<CR>
  nnoremap <silent> <F2> :call LanguageClient#textDocument_rename()<CR>
  nnoremap <leader>ld :call LanguageClient#textDocument_definition()<CR>
  nnoremap <leader>lr :call LanguageClient#textDocument_rename()<CR>
  nnoremap <leader>lf :call LanguageClient#textDocument_formatting()<CR>
  nnoremap <leader>lt :call LanguageClient#textDocument_typeDefinition()<CR>
  nnoremap <leader>lx :call LanguageClient#textDocument_references()<CR>
  nnoremap <leader>la :call LanguageClient_workspace_applyEdit()<CR>
  nnoremap <leader>lc :call LanguageClient#textDocument_completion()<CR>
  nnoremap <leader>lh :call LanguageClient#textDocument_hover()<CR>
  nnoremap <leader>ls :call LanguageClient_textDocument_documentSymbol()<CR>
  nnoremap <leader>lm :call LanguageClient_contextMenu()<CR>
endfunction

augroup LSPMappings
  autocmd!
  autocmd FileType \
    \ cpp,c,ruby,yaml,yaml.ansible,javascript,typescript,typescriptreact,javascript.jsx,sorbet,vim
    \ call LanguageClientMappers()
augroup END

let g:LanguageClient_waitOutputFTimeout = 120
let g:LanguageClient_autoStop = 0
let g:LanguageClient_serverCommands = {}
let g:LanguageClient_serverCommands.yaml = ['yaml-language-server', '--stdio']
let g:LanguageClient_serverCommands['yaml-ansible'] = ['yaml-language-server', '--stdio']
let g:LanguageClient_serverCommands.ruby = ['solargraph', 'stdio']
let g:LanguageClient_serverCommands.javascript = ['typescript-language-server', '--stdio']
let g:LanguageClient_serverCommands.typescript = ['typescript-language-server', '--stdio']
let g:LanguageClient_serverCommands['javascript.jsx'] = ['typescript-language-server', '--stdio']
let g:LanguageClient_serverCommands.typescriptreact = ['typescript-language-server', '--stdio']
let g:LanguageClient_serverCommands.rust = ['rustup', 'run', 'stable', 'rls']
let g:LanguageClient_serverCommands.vim = ['vim-language-server', '--stdio']

let lspsettings = json_decode('
\{
\    "yaml": {
\        "completion": true,
\        "hover": true,
\        "validate": true,
\        "schemas": {
\            "Kubernetes": "/*"
\        }
\    },
\    "http": {
\        "proxyStrictSSL": true
\    },
\    "ruby": {
\        "completion": true,
\        "hover": true,
\        "validate": true,
\        "typecheck": true
\    },
\    "sorbet": {
\        "completion": true,
\        "hover": true,
\        "validate": true,
\        "typecheck": true
\    },
\   "javascript": {
\        "completion": true,
\        "hover": true,
\        "validate": true
\    },
\   "typescript": {
\        "completion": true,
\        "hover": true,
\        "validate": true
\    },
\   "javascript.jsx": {
\        "completion": true,
\        "hover": true,
\        "validate": true
\    },
\   "typescriptreact": {
\        "completion": true,
\        "hover": true,
\        "validate": true
\    },
\   "vim": {
\        "completion": true,
\        "hover": true,
\        "validate": true,
\        "format": {
\            "enable": true
\        }
\    }
\}')

function InitializeLSP()
  set signcolumn=yes

  let g:LanguageClient_rootMarkers = {
  \   'javascript': ['jsconfig.json',  'package.json'],
  \   'typescript': ['tsconfig.json', 'package.json'],
  \   'javascript.jsx': ['jsconfig.json', 'package.json'],
  \   'typescriptreact': ['tsconfig.json', 'package.json'],
  \   'vim': ['.git', 'autoload', 'plugin'],
  \   'ruby': ['Gemfile', 'package.yml']
  \ }
  autocmd User LanguageClientStarted call LanguageClient#Notify(
    \ 'workspace/didChangeConfiguration', {'settings': lspsettings})
endfunction()

augroup LSP
  autocmd!
  autocmd FileType \
    \ cpp,c,ruby,yaml,yaml.ansible,javascript,typescript,typescriptreact,javascript.jsx,sorbet,vim
    \ call InitializeLSP()
augroup END
