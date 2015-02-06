module Deploku
  module Runnable

    def run_command(command, option = nil)
      Bundler.with_clean_env {
        out = `#{command}`
        if $?.success?
          if option == :echo
            puts out
          end
          out
        else
          puts "Error running command:"
          puts command
          puts out
          exit $?.exitstatus
        end
      }
    end

    def test_command(command)
      Bundler.with_clean_env {
        `#{command} 2> /dev/null`
        $?.success?
      }
    end

  end
end
