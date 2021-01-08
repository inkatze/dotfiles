" bindings ->>1

" Change leader key ->>2
let mapleader = ","
let maplocalleader = ","

" Go to alt file ->>2
nmap <leader>T :A<CR>

" Copy current buffer full path ->>2
nnoremap <silent><leader>cp :let @@ = expand('%')<CR>
nnoremap <silent><leader>cp+ :let @+ = expand('%')<CR>
nnoremap <silent><leader>CP :let @@ = expand('%:p')<CR>
nnoremap <silent><leader>CP+ :let @+ = expand('%:p')<CR>

" Buffer navigation ->>2
map <S-Left> :bp<CR>
map <S-Right> :bn<CR>


" Keep my text highlighted plz ->>2
vnoremap < <gv
vnoremap > >gv
nnoremap <silent> hl :nohl<CR>

" Folding mappings ->>2
nnoremap <space> za
nnoremap <CR> za
nnoremap <leader>f zR
nnoremap <leader>ff zM
vnoremap <space> zf

" Editor behavior ->>1
set autoread
set autowrite
set directory-=. " Wherever but here
set encoding=utf8 " UTF-8 default enconding
set expandtab " Tabs are the devil's work
set fileformats=unix,dos,mac " Prefer Unix
set hidden
set history=200
set nobackup " No backup after editing
set nowritebackup " No backups made while editing
set printoptions=paper:letter
set scroll=4 " Number of lines to scroll with ^U ^D
set softtabstop=4 " Makes you think that your spaces are tabs
set shortmess+=A " Ignore swamp files
set shortmess+=c " Don't pass messages to |ins-completion-menu|
set tabstop=4 " The all powerfull tab number
set formatoptions+=j " Smarter line joins
set completeopt+=noselect
set noshowmode
set signcolumn=yes " Always show the signcolumn

" Cosmetics
set laststatus=2 " Always show the status bar
set linebreak " Break lines by word, not by char
silent! set mouse=nvc " You can use the mouse, but not in insert mode
set number " Show line numbers
set ruler " Show row and col percentage
set scrolloff=15 " Kind of a cursor margin
set shiftround " Inteligent indent. roud the spaces of the shift width
set showbreak=↲ " Show me where you broke my lines
set showmatch " Highlight matching parentesis, braces, etc.
set sidescrolloff=3 " Side margins

" Search
set hlsearch " Highlight search
set ignorecase " Case insensitive
set incsearch " Search as you type
set infercase
set smartcase
set suffixes+=.pyc " Ignore these extensions when autocompleting files
set wildmenu " Show me possible completitions in command line
set wildmode=list:longest,full " Show me ALL posible completitions
set wildignore=*.class,*.o,*~,*.pyc,.git,node_modules " Ok, not all

" Indentation
filetype plugin indent on
set backspace=indent,eol,start

" Encoding
scriptencoding utf-8

" Color and syntax
syntax on
set cursorline

let python_highlight_all=1

" Gruvbox color scheme
set termguicolors
set background=dark
let g:gruvbox_contrast_dark='hard'
let g:gruvbox_contrast_light='soft'
let g:gruvbox_italic=1
colorscheme gruvbox

" Autofold and manual fold at the same time
set foldmarker=->>,<<-
set foldlevel=99
augroup vimrc
  au BufReadPre * setlocal foldmethod=syntax
  au BufRead * if &fdm == 'syntax' | setlocal foldmethod=marker | endif
augroup END

" http://stackoverflow.com/questions/1005/getting-root-permissions-on-a-file-inside-of-vi
cmap w!! w !sudo tee >/dev/null %

" trim spaces at EOL
command! TEOL %s/ \+$//

" performance tweaks
set lazyredraw
set redrawtime=10000
set synmaxcol=180
set re=1

autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType javascript setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType javascript.jsx setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType html setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType typescript setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType typescriptreact setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType html setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType go setlocal ts=4 sts=4 sw=4 noexpandtab autowrite
autocmd FileType json setlocal ts=2 sts=2 sw=2 conceallevel=0 expandtab
autocmd FileType fish setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType vim setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType scss setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType css setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType lua setlocal ts=2 sts=2 sw=2 expandtab
autocmd FileType proto setlocal ts=2 sts=2 sw=2 expandtab

" Python environment
let $LANG = ''
let $PYENV_ROOT = $HOME.'/.pyenv'
let $PYTHON2_VERSION = '2.7.17'
let $PYTHON3_VERSION = '3.8.5'
let $NEOVIM2_VENV = $PYENV_ROOT.'/versions/'.$PYTHON2_VERSION.'/envs/neovim2'
let $NEOVIM3_VENV = $PYENV_ROOT.'/versions/'.$PYTHON3_VERSION.'/envs/neovim3'
let g:python_host_prog = $NEOVIM2_VENV.'/bin/python'
let g:python3_host_prog = $NEOVIM3_VENV.'/bin/python'
