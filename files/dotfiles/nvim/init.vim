" Section: Plugins ->> 1
"--------------------------------------------------------------------------
runtime! partials/vim-plug.vim

" Section: Vim options ->>1
"--------------------------------------------------------------------------
runtime! partials/editor.vim

" Section: Plugin settings ->>1
"--------------------------------------------------------------------------
runtime! partials/defx.vim
runtime! partials/indentline.vim
runtime! partials/signify.vim
runtime! partials/lightline.vim
runtime! partials/ale.vim
runtime! partials/emmet.vim
runtime! partials/vim-go.vim
runtime! partials/vim-rspec.vim
runtime! partials/deoplete.vim
runtime! partials/language-client.vim
runtime! partials/echodoc.vim
runtime! partials/fzf.vim
runtime! partials/vista.vim
runtime! partials/vim-rails.vim
runtime! partials/vim-projectionist.vim
runtime! partials/vim-import-js.vim

let g:rainbow_active = 1
let g:closetag_filenames = '*.html,*.xhtml,*.phtml, *.md, *.jsx, *.html.erb, *.tsx'
map <Leader>vm <Plug>(easymotion-prefix)
