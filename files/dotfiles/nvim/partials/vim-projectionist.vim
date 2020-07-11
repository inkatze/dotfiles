let g:projectionist_heuristics = {
\   "frontend/javascripts/*": {
\     "frontend/javascripts/*.js": {
\       "alternate": "frontend/javascripts/spec/{}_spec.js"
\     },
\     "frontend/javascripts/spec/*_spec.js": {
\       "alternate": "frontend/javascripts/{}.js"
\     },
\     "frontend/javascripts/*.jsx": {
\       "alternate": "frontend/javascripts/spec/{}_spec.jsx"
\     },
\     "frontend/javascripts/spec/*_spec.jsx": {
\       "alternate": "frontend/javascripts/{}.jsx"
\     }
\   }
\ }
