require "bundler/setup"
require "rake"

$LOAD_PATH << File.expand_path("../lib", __FILE__)
require "travis/logs"
require "travis/support"
require "travis/logs/helpers/database"

namespace :db do
  desc "Apply migrations"
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

  desc "List status for migrations"
  task :status do
    Sequel.extension(:migration)
    db = Travis::Logs::Helpers::Database.create_sequel
    applied = Sequel::TimestampMigrator.new(db, "db/migrations").applied_migrations
    all_migrations = Dir["db/migrations/*.rb"].map { |file| File.basename(file) }.sort
    all_migrations.each do |migration_file|
      if applied.include?(migration_file)
        puts "   up   #{migration_file}"
      else
        puts "  down  #{migration_file}"
      end
    end
  end
end
