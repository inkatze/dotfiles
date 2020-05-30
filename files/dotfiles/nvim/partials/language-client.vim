" bindings ->>1
function  LanguageClientMappers()
  nnoremap <F5> :call LanguageClient_contextMenu()<CR>
  nnoremap <silent> gd :call LanguageClient#textDocument_definition()<CR>
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
    \ cpp,c,ruby,yaml,yaml.ansible,javascript,typescript,typescript.tsx,javascript.jsx
    \ call LanguageClientMappers()
augroup END

" LanguageClient-neovim ->>1
set runtimepath+=$HOME/.local/share/nvim/site/pack/plugins/start/LanguageClient-neovim
set hidden
set completefunc=LanguageClient#complete
set omnifunc=LanguageClient#complete

let g:LanguageClient_serverCommands = {
  \ 'yaml': ['yaml-language-server', '--stdio'],
  \ 'yaml.ansible': ['yaml-language-server', '--stdio'],
  \ 'ruby': ['solargraph', 'socket'],
  \ 'javascript': ['javascript-typescript-stdio'],
  \ 'typescript': ['javascript-typescript-stdio'],
  \ 'javascript.jsx': ['javascript-typescript-stdio'],
  \ 'typescript.tsx': ['javascript-typescript-stdio'],
  \ }
let lspsettings = json_decode('
\{
\    "yaml": {
\        "completion": true,
\        "hover": true,
\        "validate": true,
\        "schemas": {
\            "Kubernetes": "/*"
\        },
\        "format": {
\            "enable": true
\        }
\    },
\    "http": {
\        "proxyStrictSSL": true
\    },
\    "ruby": {
\        "completion": true,
\        "hover": true,
\        "validate": true,
\        "typecheck": true,
\        "format": {
\            "enable": true
\        }
\    },
\   "javascript": {
\        "completion": true,
\        "hover": true,
\        "validate": true,
\        "format": {
\            "enable": true
\        }
\    },
\   "typescript": {
\        "completion": true,
\        "hover": true,
\        "validate": true,
\        "format": {
\            "enable": true
\        }
\    },
\   "javascript.tsx": {
\        "completion": true,
\        "hover": true,
\        "validate": true,
\        "format": {
\            "enable": true
\        }
\    },
\   "typescript.tsx": {
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
    \ 'javascript': ['jsconfig.json'],
    \ 'typescript': ['tsconfig.json'],
    \ }
  autocmd User LanguageClientStarted call LanguageClient#Notify(
    \ 'workspace/didChangeConfiguration', {'settings': lspsettings})
endfunction()

augroup LSP
  autocmd!
  autocmd FileType \
    \ cpp,c,ruby,yaml,yaml.ansible,javascript,typescript,typescript.tsx,javascript.jsx
    \ call InitializeLSP()
augroup END
