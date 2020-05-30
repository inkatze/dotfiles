" bindings
" <TAB>: completion.
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"

" deoplete
autocmd InsertLeave * if pumvisible() == 0 | pclose | endif " Close preview window on leaving the insert mode

let g:deoplete#enable_at_startup = 1
let g:deoplete#custom#option#auto_complete_delay = 100
let g:deoplete#custom#option#smart_case = v:true

let g:deoplete#sources#go#gocode_binary = $GOPATH.'/bin/gocode-gomod'
let g:deoplete#sources#go#sort_class = ['package', 'func', 'type', 'var', 'const']
let g:deoplete#sources#go#builtin_objects = 1
let g:deoplete#sources#go#fallback_to_source = 1

let g:deoplete#sources#jedi#show_docstring = 1

autocmd VimEnter * silent! call deoplete#custom#source('_', 'converters', ['converter_auto_delimiter', 'remove_overlap'])
autocmd VimEnter * silent! call deoplete#custom#source('LanguageClient', 'sorters', [])
autocmd VimEnter * silent! call deoplete#initialize()
