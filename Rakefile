# frozen_string_literal: true

require "bundler/setup"
require "rspec/core/rake_task"
require "rake"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "spec/**/*_spec.rb"
end

task default: :spec

namespace :db do
  desc "Dump the database to db/dumps/<name>_<timestamp>.sql"
  task :dump do
    require "dotenv/load"
    require "uri"
    require "fileutils"

    url = ENV.fetch("DATABASE_URL", "postgresql:///sfl_compiler_dev")
    db_name = URI.parse(url).path.delete_prefix("/")
    FileUtils.mkdir_p("db/dumps")
    dump_path = "db/dumps/#{db_name}_#{Time.now.strftime('%Y%m%d%H%M%S')}.sql"

    sh "pg_dump #{db_name} -f #{dump_path}"
    puts "Dumped #{db_name} -> #{dump_path}"
  end

  desc "Drop and recreate the clauses/ideational/interpersonal/embeddings tables"
  task :refresh do
    $LOAD_PATH.unshift(File.expand_path("lib", __dir__))
    require "dotenv/load"
    require "sfl/compiler"

    ctx = SFL::Compiler::Bootstrap.call(require_llm: false)
    db = ctx.db

    %i[embeddings interpersonal_payloads ideational_payloads clauses].each do |table|
      db.run("DROP TABLE IF EXISTS #{table} CASCADE")
    end
    SFL::Compiler::Migrator.new(db).run_all

    puts "Refreshed schema for #{ctx.config.database_url}"
  end
end
