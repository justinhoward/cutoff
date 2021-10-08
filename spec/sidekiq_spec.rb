# frozen_string_literal: true

class TestCutoffWorker
  include Sidekiq::Worker

  sidekiq_options cutoff: 3

  def perform(wait)
    Timecop.freeze(wait)
    Cutoff.checkpoint!
  end
end

class TestPlainWorker
  include Sidekiq::Worker

  def perform(wait)
    Timecop.freeze(wait)
    Cutoff.checkpoint!
  end
end

RSpec.describe Cutoff::Sidekiq::ServerMiddleware do
  before do
    Timecop.freeze
    Sidekiq::Testing.inline!
  end

  it 'wraps worker with cutoff' do
    expect do
      TestCutoffWorker.perform_async(5)
    end.to raise_error(Cutoff::CutoffExceededError)
  end

  it 'does nothing if cutoff is not specified' do
    TestPlainWorker.perform_async(5)
  end
end
