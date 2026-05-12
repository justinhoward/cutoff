# frozen_string_literal:true

RSpec.describe Cutoff::Patch::NetHttp do
  it 'raises if started after cutoff expired' do
    Timecop.freeze
    Cutoff.start(2)
    Timecop.freeze(3)
    expect do
      Net::HTTP.get(URI.parse('https://example.com'))
    end.to raise_error(Cutoff::CutoffExceededError)
  end

  it 'does nothing if excluded' do
    Timecop.freeze
    Cutoff.start(2, exclude: :net_http)
    Timecop.freeze(3)
    expect(Net::HTTP.get_response(URI.parse('https://example.com')).code)
      .to eq('200')
  end

  it 'sets timeouts to remaining seconds during start' do
    Timecop.freeze
    Cutoff.start(5)
    Timecop.freeze(2)
    uri = URI.parse('https://example.com')
    Net::HTTP.start(uri.host, uri.port, read_timeout: 20) do |http|
      expect(http.read_timeout).to eq(3)
      expect(http.continue_timeout).to eq(3)
      expect(http.open_timeout).to eq(3)
    end
  end

  it 'uses existing timeout if smaller' do
    Timecop.freeze
    Cutoff.start(5)
    Timecop.freeze(2)
    uri = URI.parse('https://example.com')
    Net::HTTP.start(uri.host, uri.port, read_timeout: 1) do |http|
      expect(http.read_timeout).to eq(1)
    end
  end

  it 'does not set timeouts if excluded' do
    Timecop.freeze
    Cutoff.start(5, exclude: :net_http)
    Timecop.freeze(2)
    http = Net::HTTP.new(URI.parse('https://example.com'))
    expect(http.open_timeout).to eq(60)
    expect(http.read_timeout).to eq(60)
  end

  it 'sets write timeout for ruby >=2.6' do
    skip unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.6')

    Timecop.freeze
    Cutoff.start(5)
    Timecop.freeze(2)
    uri = URI.parse('https://example.com')
    Net::HTTP.start(uri.host, uri.port) do |http|
      expect(http.write_timeout).to eq(3)
    end
  end

  it 'does nothing if cutoff is not active' do
    expect(Net::HTTP.get_response(URI.parse('https://example.com')).code)
      .to eq('200')
  end

  it 'returns normally if response is within timeout' do
    Cutoff.start(10)
    expect(Net::HTTP.get_response(URI.parse('https://example.com')).code)
      .to eq('200')
  end

  describe "Net::HTTP's internal retry of idempotent requests" do
    # Establishes the upstream behavior the cutoff patch is guarding against:
    # Net::HTTP#transport_request silently retries idempotent requests
    # (default max_retries: 1) on Net::ReadTimeout and other transient errors,
    # which can effectively double the deadline a caller set on the request.
    it 'normally retries the request once on Net::ReadTimeout' do
      uri = URI.parse('https://example.com')
      Net::HTTP.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Get.new('/')
        attempts = 0
        allow(req).to receive(:exec) do
          attempts += 1
          raise Net::ReadTimeout
        end

        expect { http.request(req) }.to raise_error(Net::ReadTimeout)
        expect(attempts).to eq(2)
      end
    end

    it 'tightens read_timeout on each retry as the cutoff is consumed' do
      Timecop.freeze
      Cutoff.start(10)
      uri = URI.parse('https://example.com')
      Net::HTTP.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Get.new('/')
        timeouts = []
        allow(req).to receive(:exec) do
          timeouts << http.read_timeout
          Timecop.freeze(4)
          raise Net::ReadTimeout
        end

        expect { http.request(req) }.to raise_error(Net::ReadTimeout)
        expect(timeouts).to eq([10, 6])
      end
    end

    it 'short-circuits the retry with CutoffExceededError when the cutoff is exhausted' do
      Timecop.freeze
      Cutoff.start(5)
      uri = URI.parse('https://example.com')
      Net::HTTP.start(uri.host, uri.port) do |http|
        req = Net::HTTP::Get.new('/')
        attempts = 0
        allow(req).to receive(:exec) do
          attempts += 1
          Timecop.freeze(10)
          raise Net::ReadTimeout
        end

        expect { http.request(req) }.to raise_error(Cutoff::CutoffExceededError)
        expect(attempts).to eq(1)
      end
    end
  end
end
