module Deploku

  module Control
    extend Deploku::Runnable

    def self.run(args)
      matching_remotes = remotes & args
      case matching_remotes.size
      when 0
        puts "#{remotes.size} Heroku remote#{'s' if remotes.size > 1} found:"
        puts *remotes
        exit 0
      when 1
        remote = matching_remotes[0]
        args.delete remote
        commands = %w[status deploy] & args
        commands << "deploy" if commands.size == 0
        if commands.size > 1
          puts "Choose just one command"
          exit 1
        else
          args.delete commands[0]
          Deploku::Remote.new(remote).send(commands[0], args)
        end
      else
        puts "Please choose just one remote out of #{remotes.join(" or ")}"
        exit 1
      end
    end

    def self.remotes
      @remotes ||= run_command("git remote -v | grep heroku | grep push").split("\n").map {|line|
        line.match(/^(.*)\t/)[1]
      }
    end

  end

end