# frozen_string_literal: true

def setup_env_pghost
  ENV['PGHOST'] = 'localhost'
end

def setup_env_pgdatabase
  ENV['PGDATABASE'] = dbname
end

def setup_env_logs_database_url
  ENV['DATABASE_URL'] = "postgres://localhost:5432/#{dbname}"
end

def dbname
  @dbname ||= ENV.fetch(
    'TRAVIS_LOGS_TEST_ENTERPRISE_MIGRATIONS_DBNAME',
    'travis_logs_test_make_it_so'
  )
end

def shhrun(command)
  system(command, %i[out err] => '/dev/null')
end

describe 'enterprise-migrations' do
  before :all do
    Dir.chdir(File.expand_path('../..', __dir__))
  end

  after :all do
    shhrun("dropdb #{dbname} || true")
  end

  before :each do
    shhrun("dropdb #{dbname} || true")

    %w[
      PGHOST
      PGDATABASE
      DATABASE_URL
    ].each do |k|
      ENV[k] = nil
    end
  end

  context 'without PGHOST' do
    before :each do
      setup_env_pgdatabase
      setup_env_logs_database_url
    end

    it 'refuses to run' do
      expect(shhrun('script/enterprise-migrations')).to be false
    end
  end

  context 'without PGDATABASE' do
    before :each do
      setup_env_pghost
      setup_env_logs_database_url
    end

    it 'refuses to run' do
      expect(shhrun('script/enterprise-migrations')).to be false
    end
  end

  context 'without DATABASE_URL' do
    before :each do
      setup_env_pghost
      setup_env_pgdatabase
    end

    it 'refuses to run' do
      expect(shhrun('script/enterprise-migrations')).to be false
    end
  end

  context 'with required env vars' do
    before :each do
      setup_env_pghost
      setup_env_pgdatabase
      setup_env_logs_database_url
    end

    it 'runs successfully' do
      expect(shhrun('script/enterprise-migrations')).to be true
    end

    context 'with existing database' do
      before :each do
        shhrun("createdb #{dbname}")
      end

      it 'runs successfully' do
        expect(shhrun('script/enterprise-migrations')).to be true
      end

      context 'with existing logs and log_parts tables' do
        before :each do
          shhrun("psql #{dbname} <db/deploy/structure.sql")
        end

        it 'runs successfully' do
          expect(shhrun('script/enterprise-migrations')).to be true
        end
      end
    end
  end
end
