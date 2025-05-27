function zenpull
    set -xl default_notification 'company data pull completed'

    if test -z "$argv"
        echo "usage: zenpull [bash_command] [notification | '$default_notification']"
        return 1
    end

    set -xl bash_command $argv[1]
    set -xl notification $default_notification
    test -n "$argv[2]"; and set -xl notification $argv[2]

  bash -c $bash_command;
    and bin/rails db:migrate;
    and bin/rails runner 'Sidekiq::Queue.all.each(&:clear)';
    say $notification
end
