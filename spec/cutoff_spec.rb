# frozen_string_literal:true

RSpec.describe Cutoff do
  it 'records allowed_seconds as a float' do
    expect(described_class.new(3.5).allowed_seconds).to eq(3.5)
  end

  it 'reports #elapsed_seconds as time since initialized' do
    Timecop.freeze
    cutoff = described_class.new(1)
    Timecop.freeze(1)
    expect(cutoff.elapsed_seconds).to eq(1.0)
  end

  it 'reports positive #seconds_remaining before deadline' do
    Timecop.freeze
    cutoff = described_class.new(3)
    Timecop.freeze(1)
    expect(cutoff.seconds_remaining).to eq(2.0)
  end

  it 'reports negative #seconds_remaining after deadline' do
    Timecop.freeze
    cutoff = described_class.new(3)
    Timecop.freeze(6)
    expect(cutoff.seconds_remaining).to eq(-3.0)
  end

  it 'is #exceeded? once time elapses' do
    Timecop.freeze
    cutoff = described_class.new(3)
    Timecop.freeze(4)
    expect(cutoff.exceeded?).to eq(true)
  end

  it 'is not #exceeded? if there is time remaining' do
    Timecop.freeze
    cutoff = described_class.new(3)
    Timecop.freeze(2)
    expect(cutoff.exceeded?).to eq(false)
  end

  it 'passes checkpoint if there is time remaining' do
    Timecop.freeze
    cutoff = described_class.new(3)
    Timecop.freeze(2)
    cutoff.checkpoint!
  end

  it 'passes checkpoint if there is time remaining' do
    Timecop.freeze
    cutoff = described_class.new(3)
    Timecop.freeze(4)
    expect { cutoff.checkpoint! }.to raise_error(
      Cutoff::CutoffExceededError,
      'Cutoff exceeded: allowed_seconds=3.0 elapsed_seconds=4.0'
    )
  end

  it 'gets ms from seconds' do
    Timecop.freeze
    expect(described_class.new(3.5).ms_remaining).to eq(3500.0)
  end

  it 'gets the current version' do
    expect(described_class.version).to be_a(Gem::Version)
  end

  describe 'class methods' do
    it '.start and .stop push and pop from the stack' do
      Timecop.freeze
      described_class.start(8)
      expect(described_class.current.seconds_remaining).to eq(8)
      described_class.start(3)
      expect(described_class.current.seconds_remaining).to eq(3)
      described_class.stop
      expect(described_class.current.seconds_remaining).to eq(8)
      described_class.stop
      expect(described_class.current).to be_nil
    end

    it 'uses remaining time if nested cutoff is longer' do
      Timecop.freeze
      described_class.start(8)
      Timecop.freeze(2)
      described_class.start(10)
      expect(described_class.current.seconds_remaining).to eq(6)
    end

    it 'wraps a block in a cutoff on the stack' do
      Timecop.freeze
      described_class.start(8)
      described_class.wrap(3) do
        expect(described_class.current.seconds_remaining).to eq(3)
      end
      expect(described_class.current.seconds_remaining).to eq(8)
    end

    it 'recovers from a raised error in .wrap' do
      begin
        described_class.wrap(3) do
          raise 'hi'
        end
      rescue StandardError
        # Ignore
      end
      expect(described_class.current).to be_nil
    end

    it 'can be stopped when inactive' do
      described_class.stop
    end

    it 'clears all entries from the stack' do
      described_class.start(3)
      described_class.start(4)
      described_class.clear_all
      expect(described_class.current).to be_nil
    end

    it 'can stop a specific instance' do
      cutoff3 = described_class.start(3)
      cutoff4 = described_class.start(4)
      # Not the top of the stack
      described_class.stop(cutoff3)
      expect(described_class.current).to eq(cutoff4)
      described_class.stop(cutoff4)
      expect(described_class.current).to eq(cutoff3)
      described_class.stop(cutoff3)
      expect(described_class.current).to be_nil
    end

    it 'raises error at a checkpoint when active and expired' do
      Timecop.freeze
      described_class.start(3)
      Timecop.freeze(5)
      expect { described_class.checkpoint! }
        .to raise_error(Cutoff::CutoffExceededError)
    end

    it 'does nothing at a checkpoint when inactive' do
      described_class.checkpoint!
    end

    it 'does not share stack across threads' do
      Timecop.freeze
      described_class.start(3)
      Thread.new do
        expect(described_class.current).to be_nil
        described_class.start(5)
      end.join
      expect(described_class.current.seconds_remaining).to eq(3)
    end
  end
end
