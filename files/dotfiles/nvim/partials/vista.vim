" bindings
nnoremap <silent><leader>tb :Vista!!<CR>
nnoremap <silent><leader>v :Vista!!<CR>
nnoremap <leader>cr :let @@ = GetCurrentTag()<CR>
nnoremap <leader>cr+ :let @+ = GetCurrentTag()<CR>

" vista
function! NearestMethodOrFunction() abort
  return get(b:, 'vista_nearest_method_or_function', '')
endfunction

function! GetCurrentTag() abort
  if !exists('g:vista.vlnum_cache')
    echom 'Cannot copy tags outside vista buffer for now 😢'
    return
  endif
  let cursor = g:vista.get_tagline_under_cursor()

  if !exists('cursor.scope')
    return cursor.name
  endif

  " TODO: return concatenated cursor and scope if not ruby or anything in
  " particular

  let reference = substitute(cursor.scope, '\.', '::', 'g') . '.' . cursor.name
  echom 'Substitution: ' . substitute(cursor.scope, '\.', '::', 'g')
  echom 'Copied reference: ' . reference
  return reference
endfunction

set statusline+=%{NearestMethodOrFunction()}

" By default vista.vim never run if you don't call it explicitly.
"
" If you want to show the nearest function in your statusline automatically,
" you can add the following line to your vimrc
autocmd VimEnter * call vista#RunForNearestMethodOrFunction()

let g:vista_fzf_preview = ['right:50%']
let g:vista#renderer#enable_icon=1
let g:vista_echo_cursor = 0
let g:vista_echo_cursor  = 'floating_win'
