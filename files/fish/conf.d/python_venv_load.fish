status --is-login; and set -U __virtual_env ""

function __virtual_env_handler --on-event fish_prompt
  if set -q VIRTUAL_ENV
    set -U __virtual_env $VIRTUAL_ENV
    __load_python_venv
  else if test -n "$__virtual_env"
    __unload_python_venv
    set -U __virtual_env ""
  end
end

function __load_python_venv
  set -l venv_index (contains -i -- $__virtual_env/bin $fish_user_paths)
  if test -z "$venv_index"; set -U fish_user_paths $__virtual_env/bin $fish_user_paths; end
end

function __unload_python_venv
  set -l venv_index (contains -i -- $__virtual_env/bin $fish_user_paths)
  if test -n "$venv_index"; set -e fish_user_paths[$venv_index]; end
end
