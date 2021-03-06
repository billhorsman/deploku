module Deploku

  class Remote
    include Runnable

    attr_reader :remote, :maintenance, :force

    def initialize(remote)
      @remote = remote
    end

    def app_name
      @app_name ||= begin
        output = run_command("git remote -v | grep #{remote} | grep push")
        if output =~ /git@/
          output.match(/heroku[^:]*:(.*)\.git/)[1]
        else
          output.match(/\/\/[^\/]+\/(.*)\.git/)[1]
        end
      end
    end

    def remote_commit_exists_locally?
      return @remote_commit_exists_locally if defined? @remote_commit_exists_locally
      @remote_commit_exists_locally = test_command("git show #{remote_commit}")
    end

    def database_configured?
      return @database_configured if defined? @database_configured
      @database_configured = test_command("bundle exec rake db:migrate:status")
    end

    def behind
      @behind ||= count_rev_list("#{remote_commit}..")
    end

    def ahead
      @ahead ||= count_rev_list("..#{remote_commit}")
    end

    def count_rev_list(range)
      run_command("git rev-list #{range}").split("\n").size
    end

    def remote_commit
      @remote_commit ||= run_command("git ls-remote #{remote} 2> /dev/null").chomp.split(' ').first
    end

    def status(args)
      puts "Looking up current status for #{remote}"
      puts "Heroku app #{app_name} is running commit #{remote_commit.slice(0, 7)}"
      if remote_commit_exists_locally?
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
      else
        puts "Warning! The commit #{remote_commit.slice(0, 7)} is not present in the local repo. Why?"
      end
      if database_configured?
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
      repeat = true
      while repeat
        repeat = false
        print "\nChoose:\nD = deploy, or\nL = list commits to deploy, or\nanything else to abort: "
        proceed = STDIN.getch.upcase
        puts proceed
        if proceed == "D"
          puts ""
          deploy_commands.each_with_index do |command, index|
            puts "  #{index + 1}. #{command} ..."
            run_command command
          end
          puts
        elsif proceed == "L"
          puts "\nList of commits between #{remote_commit.slice(0, 7)} and local branch\n"
          run_command "git log --oneline #{remote_commit}..", :echo
          repeat = true
        else
          puts "Abort"
        end
      end
    end

    def deploy_commands
      return @deploy_commands if @deploy_commands
      maintenance_mode = false
      list = []
      if migration_required?
        case maintenance
        when :use
          maintenance_mode = true
        when :skip
          # OK, nothing to do
        else
          puts "There are migrations to run. Please either choose maintenance or maintenance:skip"
          exit 1
        end
      end
      list << "heroku maintenance:on --app #{app_name}" if maintenance_mode
      list << "git push#{force ? " --force" : ""} #{remote} #{local_branch}:master"
      list << "heroku run rake db:migrate --app #{app_name}" if migration_required?
      list << "heroku restart --app #{app_name}" if migration_required?
      list << "heroku maintenance:off --app #{app_name}" if maintenance_mode
      @deploy_commands = list
    end

    def migration_required?
      database_configured? && pending_migration_count > 0
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
      @local_migrations ||= extract_migrations(run_command("bundle exec rake db:migrate:status"), :local)
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
