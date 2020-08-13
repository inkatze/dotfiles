local iron = require('iron')

iron.core.set_config {
  preferred = {
    ruby = {
      command = {"bin/rails", "c"}
    },
    python = 'ipython'
  }
}
