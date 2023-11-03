function pft -w rspec -a test -a state -a overwrite
    if not test -n "$test"
        echo 'usage: pft [test_path] [state] [overwrite]'
        return 1
    end

    set -xl TEST_COMMAND (if test -e ./bin/rspec; echo ./bin/rspec; else; echo "bundle exec rspec"; end)
    set -xl TEST_FILE (if test -n "$test"; echo $test; else; echo .; end)
    set -xl OVERWRITE_FIXTURES (if test -n "$overwrite"; echo "$overwrite"; else; echo 1; end)
    set -xl STATE "$state"
    eval "$TEST_COMMAND $TEST_FILE"
end
