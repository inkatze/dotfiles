function gustograph
  bin/rake graphql:prepare; and \
    npx yarn generate-client-types
end

function zentags
  # --output-format=json is better, but it's not suppoorted by FZF
  ctags -R \
    --languages=all \
    --exclude=.git \
    --exclude=node_modules \
    --exclude=frontend/javascripts \
    --exclude=config \
    --exclude=script \
    --exclude=public \
    --verbose=no \
    -f tags
end

function zeni
  bundle install; and \
    yarn install; and \
    brails db:create db:migrate db:test:prepare; and \
    zentags; and \
    solarup
end

function zenu
  git pull --rebase origin development; and \
    zeni
end
