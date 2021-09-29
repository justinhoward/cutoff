# frozen_string_literal:true

RSpec.describe 'Cutoff::Patch::Mysql2', if: defined?(Mysql2) do
  let(:client) do
    Mysql2::Client.new({
      username: ENV['MYSQL_USER'],
      password: ENV['MYSQL_PASSWORD'],
      host: ENV['MYSQL_HOST'],
      port: ENV['MYSQL_PORT'],
      socket: ENV['MYSQL_SOCKET']
    })
  end

  it 'raises error if expired' do
    Timecop.freeze
    Cutoff.wrap(3) do
      Timecop.freeze(5)
      expect do
        client.query('SELECT 1 FROM dual')
      end.to raise_error(Cutoff::CutoffExceededError)
    end
  end

  it 'sets MAX_EXECUTION_TIME to remaining ms' do
    Timecop.freeze
    expect(client).to receive(:_query)
      .with('SELECT /*+ MAX_EXECUTION_TIME(2000) */ 1 FROM dual', any_args)
    Cutoff.wrap(3) do
      Timecop.freeze(1)
      client.query('SELECT 1 FROM dual')
    end
  end

  it 'does nothing if cutoff is not set' do
    expect(client).to receive(:_query)
      .with('SELECT 1 FROM dual', any_args)
    client.query('SELECT 1 FROM dual')
  end

  it 'does nothing if excluded' do
    expect(client).to receive(:_query)
      .with('SELECT 1 FROM dual', any_args)
    Timecop.freeze
    Cutoff.wrap(3, exclude: :mysql2) do
      client.query('SELECT 1 FROM dual')
    end
  end

  it 'does nothing for insert if there is time remaining' do
    expect(client).to receive(:_query)
      .with("INSERT users(first_name) VALUES('Bob')", any_args)
    Cutoff.wrap(3) do
      Timecop.freeze(1)
      client.query("INSERT users(first_name) VALUES('Bob')")
    end
  end

  it 'raises error for insert when time is expired' do
    Cutoff.wrap(3) do
      Timecop.freeze(5)
      expect do
        client.query("INSERT users(first_name) VALUES('Bob')")
      end.to raise_error(Cutoff::CutoffExceededError)
    end
  end

  describe 'Cutoff::Patch::Mysql2::QueryWithMaxTime' do
    let(:described_class) { Cutoff::Patch::Mysql2::QueryWithMaxTime }

    it 'inserts a hint into a select query' do
      query = described_class.new('SELECT * FROM users', 3)
      expect(query.to_s)
        .to eq('SELECT /*+ MAX_EXECUTION_TIME(3) */ * FROM users')
    end

    it 'inserts a hint into a query with a starting comment' do
      query = described_class.new('/* hi */ SELECT * FROM users', 3)
      expect(query.to_s).to eq(
        '/* hi */ SELECT /*+ MAX_EXECUTION_TIME(3) */ * FROM users'
      )
    end

    it 'inserts a hint into a query with a comment after select' do
      query = described_class.new('SELECT /* hi */ * FROM users', 3)
      expect(query.to_s).to eq(
        'SELECT /*+ MAX_EXECUTION_TIME(3) */ /* hi */ * FROM users'
      )
    end

    it 'inserts a hint into a query with an existing hint' do
      query = described_class.new('SELECT /*+ ANOTHER_HINT */ * FROM users', 3)
      expect(query.to_s).to eq(
        'SELECT /*+ ANOTHER_HINT MAX_EXECUTION_TIME(3) */ * FROM users'
      )
    end

    it 'inserts a hint with an existing hint with no whitespace' do
      query = described_class.new('SELECT /*+ANOTHER_HINT*/ * FROM users', 3)
      expect(query.to_s).to eq(
        'SELECT /*+ANOTHER_HINT MAX_EXECUTION_TIME(3)*/ * FROM users'
      )
    end

    it 'inserts a select hint into a select query with an empty hint' do
      query = described_class.new('SELECT /*+*/ * FROM users', 3)
      expect(query.to_s).to eq(
        'SELECT /*+MAX_EXECUTION_TIME(3)*/ * FROM users'
      )
    end

    it 'inserts into a query with an existing hint preceeded by a comment' do
      query = described_class.new('SELECT /**//*+ HI */ * FROM users', 3)
      expect(query.to_s).to eq(
        'SELECT /**//*+ HI MAX_EXECUTION_TIME(3) */ * FROM users'
      )
    end

    it 'inserts a select hint into a select query with a line comment' do
      query = described_class.new(<<~SQL, 3)
        -- this is a comment
        SELECT * FROM users
      SQL
      expect(query.to_s).to eq(<<~SQL)
        -- this is a comment
        SELECT /*+ MAX_EXECUTION_TIME(3) */ * FROM users
      SQL
    end

    it 'inserts a hint after a select with smushed line comment' do
      query = described_class.new(<<~SQL, 3)
        SELECT-- hi
        * FROM users
      SQL
      expect(query.to_s).to eq(<<~SQL)
        SELECT/*+ MAX_EXECUTION_TIME(3) */-- hi
        * FROM users
      SQL
    end

    it 'does nothing to insert statement' do
      query = described_class.new("INSERT INTO users (name) VALUES('John')", 3)
      expect(query.to_s).to eq(
        "INSERT INTO users (name) VALUES('John')"
      )
    end

    it 'inserts hint after smushed select*' do
      query = described_class.new('SELECT* FROM users', 3)
      expect(query.to_s)
        .to eq('SELECT/*+ MAX_EXECUTION_TIME(3) */ * FROM users')
    end
  end
end
