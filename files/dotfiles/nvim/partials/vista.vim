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
    echom 'References without scope are not supported 😭'
    return
  endif

  let reference = join([cursor.scope, cursor.name], '.')
  echom 'Copied: ' . reference
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
