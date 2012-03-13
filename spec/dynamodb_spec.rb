require 'spec/spec_helper'
require 'aws-sdk'
require 'dynamodb_mock'

describe 'Profiles Spec' do
  include Rack::Test::Methods
  def app
    Sinatra::Application
  end

  it "says hello" do
    get '/'
    last_response.should be_ok
  end
  
  it "should create table successfully" do
    dynamo_db = AWS::DynamoDB.new(
      :access_key_id => "...",
      :secret_access_key => "...")
      
    test_table = dynamo_db.tables.create("test1", 1, 1,
        :hash_key => { :creator_id => :number }, 
        :range_key => {:date => :number})
    
    dynamo_db.tables.to_a.length.should == 1
    dynamo_db.tables['test1'].exists?.should be_true
    # dynamo_db.tables['test_fake'].exists?.should be_false # this test fails for some reason
    
    test_table.hash_key = [:creator_id, :number]
    test_table.range_key = [:date, :number]
    
    now = Time.now.to_f
    test_table.items.put(:creator_id => 10, :date => now, :data1 => "data1")
    test_table.items[10, now].exists?.should be_true
    test_table.items[11, now].exists?.should be_false

  end
  
  
  
  it "test vistors" do
    dynamo_db = AWS::DynamoDB.new(
      :access_key_id => "...",
      :secret_access_key => "...")
    
    visitors_table = dynamo_db.tables.create("visitors", 10, 5,
        :hash_key => { :creator_id => :number }, 
        :range_key => {:date => :number})

    visitors_table.hash_key = [:creator_id, :number]
    visitors_table.range_key = [:date, :number]

    (0..10).each do |idx|      
      visitors_table.items.put(:creator_id => 1, :date => Time.now.to_f - (60 * idx), :target_id => 10 + idx)
    end

    results = visitors_table.items.query(:hash_value => 1, :scan_index_forward => false)
    results.to_a.each do |item|
      puts "#{item.attributes['target_id'].to_i} at #{Time.at(item.attributes['date'].to_f).to_s}"
    end

    puts "---"
    results = visitors_table.items.query(:hash_value => 1)
    results.to_a.each do |item|
      puts "#{item.attributes['target_id'].to_i} at #{Time.at(item.attributes['date'].to_f).to_s}"
    end

    # --
    visitors2_table = dynamo_db.tables.create("visitors2", 10, 5,
        :hash_key => { :profile_id => :number }, 
        :range_key => {:date_profile => :string})
    visitors2_table.hash_key = [:profile_id, :number]
    visitors2_table.range_key = [:date_profile, :string]
    
    profile_id = 1000
    (0..10).each do |idx|      
      timestamp = Time.now.to_f - (60 * idx)
      visitors2_table.items.put(:profile_id => idx, :date_profile => "#{timestamp}:#{profile_id}", :target_id => profile_id)
    end
    results = visitors2_table.items.query(:hash_value => 1)
    puts results.to_a.inspect
        
    # visited_table = dynamo_db.tables.create("visited", 10, 5,
    #     :hash_key => { :creator_id => :number }, 
    #     :range_key => {:date => :number})
    # 
    # visited_table.hash_key = [:creator_id, :number]
    # visited_table.range_key = [:date, :number]
    
    
    
  end
  
  # it "fake create with lib" do
  #   dynamo_db = AWS::DynamoDB.new(
  #     :access_key_id => "...",
  #     :secret_access_key => "...")
  #   
  #   table = dynamo_db.tables.create("my-table", 10, 5,
  #       :hash_key => { :id => :number }, 
  #       :range_key => {:date => :number})
  #   table.hash_key = [:id, :number]
  #   table.range_key = [:date, :number]
  #   
  #   item = table.items.create('id' => 12343, 'date' => 100, 'foo' => 'bar0', 'bizzy' => 'batty')
  #   item = table.items.create('id' => 12344, 'date' => 10, 'foo' => 'bar1', 'bizzy' => 'batty')
  #   item = table.items.create('id' => 12345, 'date' => 1, 'foo' => 'bar2', 'bizzy' => 'batty')
  #   item = table.items.create('id' => 12345, 'date' => 2, 'foo' => 'bar3', 'bizzy' => 'batty')
  #   item = table.items[12345, 1]    
  #   item.attributes['foo'].should == "bar2"
  #   item.attributes['bizzy'].should == "batty"
  #   
  #   results = table.items.query(
  #     :hash_value => 12345,
  #     :range_value => 1..10
  #   )
  # 
  #   results.to_a.length.should == 2
  #   results.to_a.first.attributes['id'].should == 12345
  #   results.to_a.first.attributes['date'].to_i.should == 1
  #   results.to_a.last.attributes['id'].should == 12345
  #   results.to_a.last.attributes['date'].to_i.should == 2
  #   
  #   table.items[12345, 1].delete()
  #   table.items[12345, 1].attributes['id'].should be_nil
  # 
  #   puts "Done"
  #       
  # end  
end
