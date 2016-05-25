$:.unshift "lib"
gem 'eventmachine', '~> 1.2.0'
gem 'pg', ENV['EM_PG_CLIENT_TEST_PG_VERSION']
require 'eventmachine'
require 'em-synchrony'
require 'pg/em'

shared_context 'test async connect timeout' do
  it "should timeout expire while connecting" do
    this = :first
    start = Time.now
    subject.connect_defer(options) do |ex|
      this = :second
      ex.should be_an_instance_of PG::ConnectionBad
      ex.message.should include 'timeout expired (async)'
      (Time.now - start).should be > timeout
      EM.stop
    end.should be_a_kind_of ::EM::Deferrable
    this.should be :first
  end

  around(:each) do |testcase|
    EM.run(&testcase)
  end
end

shared_context 'test synchrony connect timeout' do
  it "should timeout expire while connecting" do
    start = Time.now
    this = nil
    EM.next_tick { this = :that }
    expect do
      subject.new(options)
    end.to raise_error(PG::ConnectionBad, 'timeout expired (async)')
    this.should be :that
    (Time.now - start).should be > timeout
  end

  around(:each) do |testcase|
    EM.synchrony do
      begin
        testcase.call
      ensure
        EM.stop
      end
    end
  end
end

describe 'connect timeout expire' do
  subject          { PG::EM::Client }
  let(:black_hole) { '192.168.255.254' }
  let(:timeout)    { 1 }
  let(:envvar)     { 'PGCONNECT_TIMEOUT' }

  describe 'asynchronously using connect_timeout option'  do
    let(:options)  { {host: black_hole, connect_timeout: timeout} }

    before(:each) { ENV[envvar] = nil }

    include_context 'test async connect timeout'
  end

  describe 'asynchronously using PGCONNECT_TIMEOUT env var'  do
    let(:options)  { {host: black_hole} }

    before(:each) { ENV[envvar] = timeout.to_s }

    include_context 'test async connect timeout'

    after(:each) { ENV[envvar] = nil }
  end

  describe 'sync-to-fiber using connect_timeout option'  do
    let(:options)  { {host: black_hole, connect_timeout: timeout} }

    before(:each) { ENV[envvar] = nil }

    include_context 'test synchrony connect timeout'
  end

  describe 'sync-to-fiber using PGCONNECT_TIMEOUT env var'  do
    let(:options)  { {host: black_hole} }

    before(:each) { ENV[envvar] = timeout.to_s }

    include_context 'test synchrony connect timeout'

    after(:each) { ENV[envvar] = nil }
  end
end
