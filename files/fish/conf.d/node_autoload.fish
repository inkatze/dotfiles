function __node_binpath_cwd --on-variable PWD
  set -l node_modules_path "$PWD/node_modules/.bin"
  if test -e "$node_modules_path"
    set -g __node_binpath "$node_modules_path"
    set -U fish_user_paths $fish_user_paths $__node_binpath
  else
    set -q __node_binpath
      and set -l index (contains -i -- $__node_binpath $fish_user_paths)
      and set -e fish_user_paths[$index]
      and set -e __node_binpath
  end
end

__node_binpath_cwd $PWD
