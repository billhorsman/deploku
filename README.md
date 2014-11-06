# Deploku

A quick and easy way to deploy the current branch to a Heroku. It copes with multiple remotes and runs migrations as necessary. It assumes you are running a Unix like system that will execute commands like `git rev-list abcdef7.. | wc -l`, for example.

You should also look at [jbrunton/heroploy](https://github.com/jbrunton/heroploy) which is very similar to this gem. Heroploy needs some configuration (Deploku needs none) but it does do a lot more (e.g. Travis). It's also stricter about which branch can be deployed where. I encourage you to check out Heroploy as well to see if it better suits your needs.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'deploku'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install deploku

## Usage

Just run the command and it will look for any git remotes referencing Heroku:

```
[master]$ deploku
2 Heroku remotes found:
production
staging
```

Then choose a remote and run it again:

```
[master]$ deploku production
Heroku app my-app-production is running commit abcdef7
It is 3 commits behind your local master branch
There are no pending migrations
```

If you want to deploy then add the `deploy` command:

```
[master]$ deploku production deploy
Heroku app my-app-production is running commit abcdef7
It is 3 commits behind your local master branch
There are no pending migrations
The following command will be run:

  1. git push production master:master

Proceed? (y/N):
```

Enter `y` to proceed or anything else to abort. Nothing will happen unless you enter `y`.

If there are migrations pending then you will be forced to either pass in either the `maintenance` or `maintenance:skip` options.

```
[master]$ deploku production deploy maintenance
Heroku app my-app-production is running commit abcdef7
It is 3 commits behind your local master branch
There is 1 pending migration
The following commands will be run:

  1. heroku maintenance:on --app my-app-production
  2. git push production master:master
  3. heroku run rake db:migrate --app my-app-production
  4. heroku restart --app my-app-production
  5. heroku maintenance:off --app my-app-production

Proceed? (y/N):
```

## Contributing

1. Fork it ( https://github.com/billhorsman/deploku/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
