" bindings
augroup RubyMappings
  autocmd!
  autocmd FileType ruby,erb call RSpecMappings()
augroup END

function RSpecMappings()
  nmap <leader>rst :call RunCurrentSpecFile()<CR>
  nmap <leader>rsn :call RunNearestSpec()<CR>
  nmap <leader>rsl :call RunLastSpec()<CR>
endfunction

" vim-rspec
let g:rspec_command = "Dispatch bundle exec rspec {spec}"
