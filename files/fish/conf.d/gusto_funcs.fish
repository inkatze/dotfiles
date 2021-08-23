function gustograph
  bin/rake graphql:prepare; and \
    npx yarn generate-client-types
end

function zensync
  git sw development
  zenu
  git sw -
  git rebase development
end

function zenu
  set -xl rebased (git pull --rebase origin development)

  if string match -q -r 'Gemfile*' $rebased
    bundle install
  end

  if string match -q -r 'package*' $rebased
    yarn install
  end

  if string match -q -r 'db/schema.rb' $rebased
    brails db:create db:migrate db:test:prepare
  end
end
