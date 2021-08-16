function gustograph
  bin/rake graphql:prepare; and \
    npx yarn generate-client-types
end

function zeni
  bundle install; and \
    yarn install; and \
    brails db:create db:migrate db:test:prepare
end

function zensync
  git sw development
  git pull --rebase origin development
  git sw -
  git rebase development
  zeni
end

function zenu
  git pull --rebase origin development; and \
    zeni
end
