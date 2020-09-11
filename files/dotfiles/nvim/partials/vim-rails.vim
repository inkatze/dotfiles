set confirm " Ask to create alternate file if it doesn't exist
autocmd BufEnter * execute 'lcd ' . getcwd()
