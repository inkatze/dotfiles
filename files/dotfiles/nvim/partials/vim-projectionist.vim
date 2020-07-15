let g:projectionist_heuristics = {
\   "zenpayroll/frontend/javascripts/*": {
\     "zenpayroll/frontend/javascripts/*.js": {
\       "alternate": "frontend/javascripts/spec/{}_spec.js"
\     },
\     "zenpayroll/frontend/javascripts/spec/*_spec.js": {
\       "alternate": "zenpayroll/frontend/javascripts/{}.js"
\     },
\     "zenpayroll/frontend/javascripts/*.jsx": {
\       "alternate": "zenpayroll/frontend/javascripts/spec/{}_spec.jsx"
\     },
\     "zenpayroll/frontend/javascripts/spec/*_spec.jsx": {
\       "alternate": "zenpayroll/frontend/javascripts/{}.jsx"
\     }
\   }
\ }
