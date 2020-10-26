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
\     },
\     "frontend/javascripts/*.ts": {
\       "alternate": "frontend/javascripts/spec/{}_spec.ts"
\     },
\     "frontend/javascripts/spec/*_spec.ts": {
\       "alternate": "frontend/javascripts/{}.ts"
\     },
\     "frontend/javascripts/*.tsx": {
\       "alternate": "frontend/javascripts/spec/{}_spec.tsx"
\     },
\     "frontend/javascripts/spec/*_spec.tsx": {
\       "alternate": "frontend/javascripts/{}.tsx"
\     }
\   }
\ }
