function gustograph
  bin/rake graphql:prepare; and \
    npx yarn generate-client-types
end

function zensync
  git sw main
  zenu
  git sw -
  git rebase main
end

function zenu
  set -xl rebased (git pull --rebase origin main)

  if string match -q -r 'Gemfile*' $rebased
    bundle install
  end

  if string match -q -r 'package.json|yarn.lock' $rebased
    yarn install
  end

  if string match -q -r 'db/schema.rb' $rebased
    brails db:create db:migrate db:test:prepare
  end

  set -xl rebased (git status)
  if string match -q -r 'db/schema.rb' $rebased
    echo 'db/schema.rb is out of sync'
    git restore db/schema.rb
  end
end
