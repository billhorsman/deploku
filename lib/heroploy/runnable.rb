module Heroploy
  module Runnable

    def run_command(command)
      Bundler.with_clean_env {
        out = `#{command}`
        if $?.success?
          out
        else
          puts "Error running command:"
          puts command
          puts out
          exit $?.exitstatus
        end
      }
    end

  end
end
