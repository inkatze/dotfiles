" setup ->>1
let s:default_columns = 'indent:git:icons:filename'"
let s:ignored_files = '.mypy_cache,.pytest_cache,.git,.hg,.svn,.stversions'
  \ . ',__pycache__,.sass-cache,*.egg-info,.DS_Store,*.pyc'
function! s:setup_defx() abort
  silent! call defx#custom#option('_', {
  \   'resume': 1,
  \   'winwidth': 40,
  \   'columns': s:default_columns,
  \   'split': 'vertical',
  \   'direction': 'topleft',
  \   'root_marker': '',
  \   'show_ignored_files': 0,
  \   'ignored_files': s:ignored_files,
  \ })
  silent! call defx#custom#column('mark', { 'readonly_icon': '', 'selected_icon': '' })
  silent! call defx#custom#column('filename', { 'root_marker_highlight': 'Comment' })
  silent! call s:defx_open({ 'dir': expand('<afile>') })
endfunction

" bindings ->>1
nnoremap <silent><Leader>n :call <sid>defx_open({ 'find_current_file': v:true })<CR>
nnoremap <silent><C-n> :call <sid>defx_open({ 'find_current_file': v:true })<CR>
nnoremap <silent><Leader>hf :call <sid>defx_open({ 'find_current_file': v:true })<CR>

" bindings when in defx buffer ->>1
function! s:defx_mappings() abort
  nnoremap <silent><buffer><expr> o <sid>defx_toggle_node()
  nnoremap <silent><buffer><expr> O defx#do_action('open_tree_recursive')
  nnoremap <silent><buffer><expr> <CR> <sid>defx_toggle_node()
  nnoremap <silent><buffer><expr> <2-LeftMouse> <sid>defx_toggle_node()
  nnoremap <silent><buffer><expr> C defx#is_directory() ? defx#do_action('multi', ['open', 'change_vim_cwd']) : 'C'
  nnoremap <silent><buffer><expr> s defx#do_action('open', 'botright vsplit')
  nnoremap <silent><buffer><expr> R defx#do_action('redraw')
  nnoremap <silent><buffer><expr> U defx#do_action('multi', [['cd', '..'], 'change_vim_cwd'])
  nnoremap <silent><buffer><expr> . defx#do_action('toggle_ignored_files')
  nnoremap <silent><buffer><expr> <Space> defx#do_action('toggle_select') . 'j'
  nnoremap <silent><buffer><expr> j line('.') == line('$') ? 'gg' : 'j'
  nnoremap <silent><buffer><expr> k line('.') == 1 ? 'G' : 'k'
  nnoremap <silent><buffer> J :call search('[]')<CR>
  nnoremap <silent><buffer> K :call search('[]', 'b')<CR>
  nnoremap <silent><buffer><expr> yy defx#do_action('yank_path')
  nnoremap <silent><buffer><expr> a defx#do_action('new_multiple_files')
  nnoremap <silent><buffer><expr> r defx#do_action('rename')
  nnoremap <nowait><silent><buffer><expr> c defx#do_action('copy')
  nnoremap <silent><buffer><expr> x defx#do_action('move')
  nnoremap <silent><buffer><expr> X defx#do_action('execute_system')
  nnoremap <silent><buffer><expr> p defx#do_action('paste')
  nnoremap <nowait><silent><buffer><expr> d defx#do_action('remove')
  nnoremap <silent><buffer><expr> q defx#do_action('quit')
  nnoremap <silent><buffer><expr> <Leader>n defx#do_action('quit')
  nnoremap <silent><buffer><expr> <C-n> defx#do_action('quit')
  nnoremap <silent><buffer><expr> P     defx#do_action('preview')
  silent exe 'nnoremap <silent><buffer><expr> tt defx#do_action("toggle_columns", "'.s:default_columns.':size:time")'
endfunction

" defx-icons ->>1
let g:defx_icons_column_length = 1
let g:defx_icons_mark_icon = ''

" events ->>1
augroup neovim_defx
  autocmd!
  autocmd FileType defx call <SID>defx_mappings()
  autocmd VimEnter * call <SID>setup_defx()
  autocmd BufWritePost * call defx#redraw()
augroup END

" internal ->>1
function s:get_project_root() abort
  let l:git_root = ''
  let l:path = expand('%:p:h')
  let l:cmd = systemlist('cd '.l:path.' && git rev-parse --show-toplevel')
  if !v:shell_error && !empty(l:cmd)
    let l:git_root = fnamemodify(l:cmd[0], ':p:h')
  endif

  if !empty(l:git_root)
    return l:git_root
  endif

  return getcwd()
endfunction

function! s:defx_open(...) abort
  let l:opts = get(a:, 1, {})
  let l:is_file = has_key(l:opts, 'dir') && !isdirectory(l:opts.dir)

  if  &filetype ==? 'defx' || l:is_file
    return
  endif

  let l:path = s:get_project_root()

  if has_key(l:opts, 'dir') && isdirectory(l:opts.dir)
    let l:path = l:opts.dir
  endif

  if has_key(l:opts, 'find_current_file')
    call execute(printf('Defx -search=%s %s', expand('%:p'), l:path))
  else
    call execute(printf('Defx -toggle %s', l:path))
    call execute('wincmd p')
  endif

  return execute("norm!\<C-w>=")
endfunction

function s:defx_toggle_node() abort
  if defx#is_directory()
    return defx#do_action('open_or_close_tree')
  endif
  return defx#do_action('drop')
endfunction
