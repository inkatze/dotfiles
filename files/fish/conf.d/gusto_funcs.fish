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
  set -xl REBASED (git pull --rebase origin development)

  echo $REBASED

  if string match -q -r 'Gemfile*' $REBASED
    bundle install
  end

  if string match -q -r 'package*' $REBASED
    yarn install
  end

  if string match -q -r 'db/schema.rb' $REBASED
    brails db:create db:migrate db:test:prepare
  end
end
