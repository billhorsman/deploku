module Deploku

  module Control
    extend Deploku::Runnable

    def self.run(args)
      matching_remotes = remotes & args
      if matching_remotes.size == 0 && remote_index_uniq?
        if key = (remote_index.keys & args)[0]
          matching_remotes = [remote_index[key]]
          args.delete key
        end
      end
      case matching_remotes.compact.size
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

    def self.remote_index_uniq?
      remote_index.size == remotes.size
    end

    def self.remote_index
      @remote_index ||= Hash[remotes.map{|r| [r.slice(0, 1), r] }]
    end

  end

end