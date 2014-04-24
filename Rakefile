require "bundler/setup"
require "rake"

$LOAD_PATH << File.expand_path("../lib", __FILE__)
require "travis/logs"
require "travis/support"
require "travis/logs/helpers/database"

namespace :db do
  task :migrate, [:version] do |t, args|
    Sequel.extension(:migration)
    db = Travis::Logs::Helpers::Database.create_sequel

    if args[:version]
      puts "Migrating to version #{args[:version]}"
      Sequel::Migrator.run(db, "db/migrations", target: args[:version].to_i)
    else
      puts "Migrating to latest"
      Sequel::Migrator.run(db, "db/migrations")
    end
  end
end
