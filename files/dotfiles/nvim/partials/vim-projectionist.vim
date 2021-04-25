let g:projectionist_heuristics = {}

" Rails stuff
let g:projectionist_heuristics["packs/cashout/*"] = {}

" Public API
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/app/public/*.rb"] = {}
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/app/public/*.rb"].type = "source"
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/app/public/*.rb"].alternate = [
  \ "packs/cashout/spec/{}_spec.rb",
  \ "packs/cashout/spec/{}_integration_spec.rb"
  \ ]
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/app/public/*.rb"].template = [
  \ "# @mission Modern Bank",
  \ "# @team Cashout",
  \ "# typed: strict",
  \ "# frozen_string_literal: true"
  \ ]

" Lib
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/lib/*.rb"] = {}
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/lib/*.rb"].type = "source"
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/lib/*.rb"].alternate = [
  \ "packs/cashout/spec/{}_spec.rb",
  \ "packs/cashout/spec/{}_integration_spec.rb"
  \ ]
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/lib/*.rb"].template = [
  \ "# @mission Modern Bank",
  \ "# @team Cashout",
  \ "# typed: strict",
  \ "# frozen_string_literal: true"
  \ ]

" App
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/app/*.rb"] = {}
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/app/*.rb"].type = "source"
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/app/*.rb"].alternate = "packs/cashout/spec/{}_spec.rb"
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/app/*.rb"].template = [
  \ "# @mission Modern Bank",
  \ "# @team Cashout",
  \ "# typed: strict",
  \ "# frozen_string_literal: true"
  \ ]
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_spec.rb"] = {}
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_spec.rb"].type = "test"
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_spec.rb"].alternate = "packs/cashout/app/{}.rb"
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_spec.rb"].template = [
  \ "# @mission Modern Bank",
  \ "# @team Cashout",
  \ "# frozen_string_literal: true"
  \ ]

" Specs
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_spec.rb"] = {}
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_spec.rb"].type = "test"
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_spec.rb"].alternate = [
  \ "packs/cashout/app/public/{}.rb",
  \ "packs/cashout/lib/{}.rb",
  \ ]
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_spec.rb"].template = [
  \ "# @mission Modern Bank",
  \ "# @team Cashout",
  \ "# frozen_string_literal: true",
  \ "",
  \ "require 'rails_helper'",
  \ "require '{}'"
  \ ]
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_integration_spec.rb"] = {}
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_integration_spec.rb"].type = "test"
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_integration_spec.rb"].alternate = [
  \ "packs/cashout/app/public/{}.rb",
  \ "packs/cashout/lib/{}.rb",
  \ ]
let g:projectionist_heuristics["packs/cashout/*"]["packs/cashout/spec/*_integration_spec.rb"].template = [
  \ "# @mission Modern Bank",
  \ "# @team Cashout",
  \ "# frozen_string_literal: true",
  \ "",
  \ "require 'rails_helper'",
  \ "require '{}'"
  \ ]

" Node stuff
let g:projectionist_heuristics["frontend/javascripts/*"] = {}
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.js"] = {}
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.js"].type = "source"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.js"].alternate = ["frontend/javascripts/{}.test.js", "frontend/javascripts/spec/{}_spec.js"]
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.js"].template = ["// @mission Modern Bank", "// @team Cashout"]
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.jsx"] = {}
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.jsx"].type = "source"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.jsx"].alternate = ["frontend/javascripts/{}.test.jsx", "frontend/javascripts/spec/{}_spec.jsx"]
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.jsx"].template = ["// @mission Modern Bank", "// @team Cashout"]
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.ts"] = {}
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.ts"].type = "source"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.ts"].alternate = ["frontend/javascripts/{}.test.ts", "frontend/javascripts/spec/{}_spec.ts"]
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.ts"].template = ["// @mission Modern Bank", "// @team Cashout"]
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.tsx"] = {}
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.tsx"].type = "source"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.tsx"].alternate = ["frontend/javascripts/{}.test.tsx", "frontend/javascripts/spec/{}_spec.tsx"]
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.tsx"].template = ["// @mission Modern Bank", "// @team Cashout"]

let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.js|frontend/javascripts/spec/*_spec.js"] = {}
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.js|frontend/javascripts/spec/*_spec.js"].type = "test"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.js|frontend/javascripts/spec/*_spec.js"].alternate = "frontend/javascripts/{}.js"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.js|frontend/javascripts/spec/*_spec.js"].template = ["// @mission Modern Bank", "// @team Cashout"]
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.jsx|frontend/javascripts/spec/*_spec.jsx"] = {}
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.jsx|frontend/javascripts/spec/*_spec.jsx"].type = "test"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.jsx|frontend/javascripts/spec/*_spec.jsx"].alternate = "frontend/javascripts/{}.jsx"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.jsx|frontend/javascripts/spec/*_spec.jsx"].template = ["// @mission Modern Bank", "// @team Cashout"]
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.ts|frontend/javascripts/spec/*_spec.ts"] = {}
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.ts|frontend/javascripts/spec/*_spec.ts"].type = "source"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.ts|frontend/javascripts/spec/*_spec.ts"].alternate = "frontend/javascripts/{}.ts"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.ts|frontend/javascripts/spec/*_spec.ts"].template = ["// @mission Modern Bank", "// @team Cashout"]
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.tsx|frontend/javascripts/spec/*_spec.tsx"] = {}
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.tsx|frontend/javascripts/spec/*_spec.tsx"].type = "source"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.tsx|frontend/javascripts/spec/*_spec.tsx"].alternate = "frontend/javascripts/{}.tsx"
let g:projectionist_heuristics["frontend/javascripts/*"]["frontend/javascripts/*.test.tsx|frontend/javascripts/spec/*_spec.tsx"].template = ["// @mission Modern Bank", "// @team Cashout"]
