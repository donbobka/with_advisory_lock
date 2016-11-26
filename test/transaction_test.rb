require 'minitest_helper'

describe 'transaction scoping' do
  def supported?
    env_db == :postgresql
  end

  describe 'supported' do
    before do
      skip unless env_db == :postgresql
    end

    def pg_lock_count
      ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM pg_locks WHERE locktype = 'advisory';").to_i
    end

    specify 'session locks release after the block executes' do
      Tag.transaction do
        pg_lock_count.must_equal 0
        Tag.with_advisory_lock 'test' do
          pg_lock_count.must_equal 1
        end
        pg_lock_count.must_equal 0
      end
    end

    specify 'session locks release when transaction fails inside block' do
      Tag.transaction do
        pg_lock_count.must_equal 0

        exception = proc {
          Tag.with_advisory_lock 'test' do
            Tag.connection.execute 'SELECT 1/0;'
          end
        }.must_raise ActiveRecord::StatementInvalid
        exception.message.must_include 'division by zero'

        pg_lock_count.must_equal 0
      end
    end
  end
end
