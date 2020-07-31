call plug#begin(stdpath('data') . '/site')

" color schemes ->>1
Plug 'morhetz/gruvbox'
Plug 'AlessandroYorba/Sierra'

" linting ->>1
Plug 'dense-analysis/ale'

" language support ->>1

" ungrouped ->> 2
Plug 'pearofducks/ansible-vim', { 'for': ['yaml', 'yaml.ansible'] }
Plug 'dag/vim-fish', { 'for': 'fish' }
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }

" javascripts ->>2
Plug 'pangloss/vim-javascript', { 'for': ['javascript', 'javascript.jsx'] }
Plug 'mxw/vim-jsx', { 'for': 'javascript.jsx' }
Plug 'leafgarland/typescript-vim', { 'for': ['typescript', 'typescript.tsx'] }
Plug 'peitalin/vim-jsx-typescript', { 'for': 'typescript.tsx' }
Plug 'Galooshi/vim-import-js', { 'for': ['javascript', 'javascript.jsx', 'typescript', 'typescript.tsx'] }

" ruby ->>2
Plug 'tpope/vim-rails', { 'for': 'ruby' }
Plug 'tpope/vim-rake', { 'for': 'ruby' }
Plug 'tpope/vim-bundler', { 'for': 'ruby' }
Plug 'tpope/vim-rbenv', { 'for': 'ruby' }
Plug 'thoughtbot/vim-rspec', { 'for': 'ruby' }
Plug 'vim-ruby/vim-ruby', { 'for': 'ruby' }

" python ->>2
Plug 'numirias/semshi', {'do': ':UpdateRemotePlugins', 'for': 'python'} " python highlighting
Plug 'tmhedberg/SimpylFold', { 'for': 'python' } " python folding

" rust ->>2
Plug 'rust-lang/rust.vim', { 'for': 'python' }

" everything else bagel ->>2
Plug 'autozimu/LanguageClient-neovim', {
  \ 'branch': 'next',
  \ 'do': 'bash install.sh',
  \ }

" editing / qol ->>1
Plug 'jiangmiao/auto-pairs'
Plug 'Shougo/echodoc' " shows signatures in status bar
Plug 'mattn/emmet-vim' " expans abbreviations
Plug 'tpope/vim-projectionist' " ruby project manager
Plug 'tpope/vim-dispatch' " async task runner
Plug 'tpope/vim-endwise' " adds ending tokens for ruby
Plug 'Yggdroot/indentLine' " shows indentation guides
Plug 'tpope/vim-surround'
Plug 'alvan/vim-closetag' " close html tags
Plug 'tpope/vim-commentary'
Plug 'luochen1990/rainbow' " colored parenthesis
Plug 'gregsexton/MatchTag' " highlight matching html tags
Plug '907th/vim-auto-save'
Plug 'easymotion/vim-easymotion'

" tmux
Plug 'tmux-plugins/vim-tmux'
Plug 'tmux-plugins/vim-tmux-focus-events'

" misc utils ->>1
Plug 'kristijanhusak/vim-carbon-now-sh' " code screenshots
Plug 'psliwka/vim-smoothie' " smooth scrolling
Plug 'tpope/vim-eunuch' " common unix commands
Plug '907th/vim-auto-save'
Plug 'ryanoasis/vim-devicons'

" git ->>1
Plug 'tpope/vim-fugitive'
Plug 'mhinz/vim-signify'

" file browser ->>1
Plug 'Shougo/defx.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'kristijanhusak/defx-icons'
Plug 'kristijanhusak/defx-git'
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'jeetsukumaran/vim-buffergator'
Plug 'liuchengxu/vista.vim'

" completion ->>1
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'deoplete-plugins/deoplete-go', { 'do': 'make', 'for': 'go'}
Plug 'deoplete-plugins/deoplete-jedi', { 'for': 'python' }
Plug 'etordera/deoplete-rails', { 'for': 'ruby' }

" status bars(s) ->>1
Plug 'itchyny/lightline.vim' | Plug 'mengelbrecht/lightline-bufferline'

" markdown composer ->>1
function! BuildComposer(info)
  if a:info.status != 'unchanged' || a:info.force
    if has('nvim')
      !cargo build --release --locked
    else
      !cargo build --release --locked --no-default-features --features json-rpc
    endif
  endif
endfunction
Plug 'euclio/vim-markdown-composer', { 'do': function('BuildComposer') }

call plug#end()
