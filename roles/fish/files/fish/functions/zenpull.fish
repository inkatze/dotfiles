function usage
  echo 'usage: zenpull [bash_command] [notification]'
  return 1
end

function zenpull
  if test -z "$argv[1]"
    or test -z "$argv[2]"
    return usage()
  end

  set -xl bash_command $argv[1]
  set -xl notification $argv[2]

  bash -c $bash_command;
    and bin/rails db:migrate;
    and bin/rails runner 'Sidekiq::Queue.all.each(&:clear)';
    and bin/rails pufferfish:generate_filing_artifacts;
    say $notification
end
