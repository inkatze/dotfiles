" lightline
let g:lightline#bufferline#enable_devicons=1
let g:lightline#bufferline#unicode_symbols=1
let g:lightline#bufferline#clickable=1
let g:lightline#bufferline#filename_modifier = ':t'

let g:lightline = {
\   'colorscheme': 'one',
\   'active': {
\     'left': [ [ 'mode', 'paste', 'gitbranch' ], [ 'readonly', 'relativepath', 'method' ] ]
\   },
\   'tabline': {
\     'left': [ ['buffers'] ],
\     'right': []
\   },
\   'component_function': {
\     'method': 'NearestMethodOrFunction',
\     'relativepath': 'LightlineRelativepath',
\     'gitbranch': 'GitBranch',
\     'readonly': 'LightlineReadonly'
\   },
\   'component_expand': {
\     'buffers': 'lightline#bufferline#buffers'
\   },
\   'component_type': {
\     'buffers': 'tabsel'
\   },
\   'component_raw': {
\     'buffers': 1
\   },
\   'mode_map': {
\     'n' : 'N',
\     'i' : 'I',
\     'R' : 'R',
\     'v' : 'V',
\     'V' : 'VL',
\     "\<C-v>": 'VB',
\     'c' : 'C',
\     's' : 'S',
\     'S' : 'SL',
\     "\<C-s>": 'SB',
\     't': 'T',
\   }
\ }

" hide read only components
function! LightlineReadonly()
  return &readonly && &filetype !~# '\v(help|vimfiler|unite)' ? '' : ''
endfunction

function! LightlineRelativepath()
  let filename = expand('%:t') !=# '' ? expand('%') : '*'
  let modified = &modified ? ' ✎' : ''
  return filename . modified
endfunction

function! GitBranch()
  return ' ' . FugitiveHead()
endfunction

let g:unite_force_overwrite_statusline = 0
let g:vimfiler_force_overwrite_statusline = 0

" lightline-bufferline
set showtabline=2
