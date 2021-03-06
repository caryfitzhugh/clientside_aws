# Set your path to the redis-server binary here
ENV['RACK_ENV'] = 'test'

require 'index'
require 'sinatra'
require 'rspec'
require 'rack/test'
require 'crack'

Sinatra::Base.set :environment, :test
Sinatra::Base.set :run, false
Sinatra::Base.set :raise_errors, true
Sinatra::Base.set :logging, false

RSpec.configure do |config|
  config.include Rack::Test::Methods
  @pid1
  
  config.before(:suite) do
    @pid1 = fork do
      $stdout = File.new('/dev/null', 'w')
      File.open("test1.conf", 'w') {|f| f.write("port 6380\ndbfilename test1.rdb\nloglevel warning") }
      exec "redis-server test1.conf"
    end
    puts "PID1 is #{@pid1}\n\n"
    sleep(3)

    clean_redis
  end

  config.after(:suite) do
    clean_redis

    puts "Killing redis-server"
    
    STDOUT.flush
    Process.kill("KILL", @pid1)
    FileUtils.rm "test1.rdb" if File.exists?("test1.rdb")
    FileUtils.rm "test1.conf" if File.exists?("test1.conf")
    Process.waitall
  end

end

def clean_redis
  raise "cannot flush" unless ENV['RACK_ENV'] == "test"  
  AWS_REDIS.flushdb
end
