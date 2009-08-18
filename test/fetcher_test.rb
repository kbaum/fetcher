# require File.dirname(__FILE__) + '/../../../../config/boot'
require 'rubygems'
require 'test/unit'
require 'mocha'
require 'fetcher'
require 'ruby-debug'

class FetcherTest < Test::Unit::TestCase
  
  def setup
    @receiver = mock()
  end
  
  def test_should_set_configuration_instance_variables
    create_fetcher
    assert_equal 'test.host', @fetcher.instance_variable_get(:@server)
    assert_equal 'name', @fetcher.instance_variable_get(:@username)
    assert_equal 'password', @fetcher.instance_variable_get(:@password)
    assert_equal @receiver, @fetcher.instance_variable_get(:@receiver)
  end

  def test_fetch
    create_fetcher
    @fetcher.expects(:establish_connection)
    @fetcher.expects(:get_messages).raises(RuntimeError.new('error'))
    @fetcher.expects(:close_connection)
    assert_raise RuntimeError do
      @fetcher.fetch
    end
  end
  
  def test_should_require_subclass
    create_fetcher
    assert_raise(NotImplementedError) { @fetcher.fetch }
  end
  
  def test_should_require_server
    assert_raise(ArgumentError) { create_fetcher(:server => nil) }
  end
  
  def test_should_require_username
    assert_raise(ArgumentError) { create_fetcher(:username => nil) }
  end
  
  def test_should_require_password
    assert_raise(ArgumentError) { create_fetcher(:password => nil) }
  end
  
  def test_should_require_receiver
    assert_raise(ArgumentError) { create_fetcher(:receiver => nil) }
  end
  
  def create_fetcher(options={})
    @fetcher = Fetcher::Base.new({:server => 'test.host', :username => 'name', :password => 'password', :receiver => @receiver}.merge(options))
  end
  
end

class FactoryFetcherTest < Test::Unit::TestCase
  
  def setup
    @receiver = mock()
    @pop_fetcher = Fetcher.create(:type => :pop, :server => 'test.host',
      :username => 'name',
      :password => 'password',
      :receiver => @receiver)
    
    @imap_fetcher = Fetcher.create(:type => :imap, :server => 'test.host',
      :username => 'name',
      :password => 'password',
      :receiver => @receiver)
  end
  
  def test_should_be_sublcass
    assert_equal Fetcher::Pop, @pop_fetcher.class
    assert_equal Fetcher::Imap, @imap_fetcher.class
  end
  
  def test_should_require_type
    assert_raise(ArgumentError) { Fetcher.create({}) }
  end
  
end

# Write tests for sub-classes

class ImapTest < Test::Unit::TestCase

  def setup
    @server = 'test.host'
    @username = 'name'
    @password = 'password'
    @imap = Fetcher::Imap.new( :receiver => mock(),
      :server => @server,
      :username => @username,
      :password => @password,
      :use_login=>true,
      :processed_folder=>'processed'
    )
  end

  def test_close_connection_with_nil_connection
    @imap.send(:close_connection)
  end

  def test_get_messages
    establish_connection
    @connection.expects(:select).with('INBOX')
    @uids = [1,2,3,4]
    @connection.expects(:uid_search).with(['ALL']).returns(@uids)
    @messages = @uids.collect do |uid|
      @message = "message_#{uid}"
      @connection.expects(:uid_fetch).with(uid, 'RFC822').returns([stub(:attr=>{'RFC822'=>@message})])
      [@message, uid]
    end
    @messages.each do |msg_uid_array|
      msg = msg_uid_array.first
      uid = msg_uid_array.last
      @imap.expects(:process_message).with(msg)
      @imap.expects(:add_to_processed_folder).with(uid)
      @connection.expects(:uid_store).with(uid, "+FLAGS", [:Seen, :Deleted])
    end
    @imap.fetch
  end

  protected

  def establish_connection
    @connection = mock()
    Net::IMAP.expects(:new).with(@server, 143, nil).returns(@connection)
    @connection.expects(:login).with(@username, @password)
  end


end