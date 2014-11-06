module Deploku

  class Remote
    include Runnable

    attr_reader :remote, :maintenance, :force

    def initialize(remote)
      @remote = remote
    end

    def app_name
      @app_name ||= run_command("git remote -v | grep #{remote} | grep push").match(/heroku\.com:(.*)\.git/)[1]
    end

    def behind
      @behind ||= run_command("git rev-list #{remote_commit}.. | wc -l").strip.to_i
    end

    def ahead
      @ahead ||= run_command("git rev-list ..#{remote_commit} | wc -l").strip.to_i
    end

    def remote_commit
      @remote_commit ||= run_command("git ls-remote #{remote} 2> /dev/null").chomp.split(' ').first
    end

    def status(args)
      puts "Heroku app #{app_name} is running commit #{remote_commit.slice(0, 7)}"
      if behind == 0 && ahead == 0
        puts "It is up to date"
      else
        if ahead == 0
          puts "It is #{behind} commit#{"s" if behind > 1} behind your local #{local_branch} branch"
        elsif behind == 0
          puts "It is #{ahead} commit#{"s" if ahead > 1} ahead of your local #{local_branch} branch"
        else
          puts "It is #{behind} commit#{"s" if behind > 1} behind and #{ahead} commit#{"s" if ahead > 1} ahead of your local #{local_branch} branch"
        end
      end
      case pending_migration_count
      when 0
        puts "There are no pending migrations"
      when 1
        puts "There is 1 pending migration"
      else
        puts "There are #{pending_migration_count} pending migrations"
      end
      if pending_migration_count > 0
        pending_migrations.each do |migration|
          puts migration
        end
      end
    end

    def deploy(args)
      status(args)
      @force = !!args.delete("force")
      if args.delete("maintenance")
        @maintenance = :use
      elsif args.delete("maintenance:skip")
        @maintenance = :skip
      end
      if args.any?
        puts "Unknown argument(s): #{args.join(", ")}"
        exit 1
      end
      puts "The following command#{'s' if deploy_commands.size > 1} will be run:"
      puts
      deploy_commands.each_with_index do |command, index|
        puts "  #{index + 1}. #{command}"
      end
      print "\nProceed? (y/N): "
      proceed = STDIN.gets.strip
      if proceed == "y"
        puts ""
        deploy_commands.each_with_index do |command, index|
          puts "  #{index + 1}. #{command} ..."
          run_command command
        end
        puts
      else
        puts "Abort"
      end
    end

    def deploy_commands
      return @deploy_commands if @deploy_commands
      maintenance_mode = pending_migration_count > 0 && maintenance == :use
      list = []
      if pending_migration_count > 0
        case maintenance
        when :use
          maintenance_mode = true
        when :skip
          maintenance_mode = false
        else
          puts "There are migrations to run. Please either choose maintenance or maintenance:skip"
          exit 1
        end
      end
      list << "heroku maintenance:on --app #{app_name}" if maintenance_mode
      list << "git push#{force ? " --force" : ""} #{remote} #{local_branch}:master"
      list << "heroku run rake db:migrate --app #{app_name}" if pending_migration_count > 0
      list << "heroku restart --app #{app_name}" if pending_migration_count > 0
      list << "heroku maintenance:off --app #{app_name}" if maintenance_mode
      @deploy_commands = list
    end

    def local_branch
      @local_branch ||= run_command("git symbolic-ref HEAD").chomp.sub(/^\/?refs\/heads\//, '')
    end

    def pending_migration_count
      pending_migrations.size
    end

    def migrations
      local_migrations && remote_migrations # Triggers building of @migrations
      @migrations.sort_by(&:version)
    end

    def pending_migrations
      migrations.select(&:pending?)
    end

    def add_migration(hash)
      @migrations ||= []
      migration = @migrations.detect {|m| m.version == hash[:version] } || Deploku::Migration.new(version: hash[:version])
      if hash[:location] == :local
        migration.local_status = hash[:status]
      else
        migration.remote_status = hash[:status]
      end
      @migrations << migration
    end

    def local_migrations
      @local_migrations ||= extract_migrations(run_command("rake db:migrate:status"), :local)
    end

    def remote_migrations
      @remote_migrations ||= extract_migrations(run_command("heroku run rake db:migrate:status --app #{app_name}"), :remote)
    end

    def extract_migrations(output, location)
      output.split("\n").
        select {|line|
          line =~ /^\s*(up|down)/
        }.map {|line|
          values = line.split(" ")
          add_migration(
            location: location,
            version: values[1],
            status: values[0],
          )
        }
    end

  end

end