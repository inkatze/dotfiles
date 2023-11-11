function usage
  echo 'usage: notify title message [open]'
  return 1
end

# sound guide: Blow => succes, Sosumi => error, Purr => info
function notify
  if test -z "$argv[1]"
    or test -z "$argv[2]"
    return usage()
  end

  set -xl title $argv[1]
  set -xl message $argv[2]
  set -xl options $argv[3]

  terminal-notifier -title $title -message $message $options
end
