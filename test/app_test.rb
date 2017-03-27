#Get started with testing Sinatra apps:
# 1. use get/post or other named methods
# 2. access the response with last_response, which returns a
# Rack::MockResponse object, which you can call 'status', 'body',
# and '[]' on
# 3. Make assertions against values in the response

ENV["RACK_ENV"] = "test" #This value is used by various parts
# of Sinatra and Rack to know if the code is being test, and in 
# the case of Sinatra, determine whether it will start a web
# server or not (we don't want to if we're running tests)

require "minitest/autorun" #these are the two libraries we need
require "rack/test"        #for testing
require "fileutils"        #necessary to make test dir/files for tests

require_relative "../cms"

class AppTest < Minitest::Test #test methods need to be defined in in a class that subclasses Minitest::Test
  include Rack::Test::Methods # gain access to useful testing helper methods

  def app
    Sinatra::Application
  end

  def setup
    FileUtils.mkdir_p(data_path) #Note that we can access the data_path method defined
                                 #in cms.rb, because it was defined in global scope
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def test_index #Minitest uses methods whose names start with test_
    create_document "about.md"
    create_document "changes.txt"

    get '/'

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_file
    create_document("about.txt", "Ruby copyright 2017")

    get '/about.txt'

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby copyright 2017"
  end

  def test_unknown_file
    get '/other.txt'

    assert_equal 302, last_response.status
    
    get last_response["Location"] #I used get '/' which did the same I think
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "does not exist"
  end

  def test_markdown_render
    create_document("about.md", "#Ruby is...")

    get '/about.md'

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_editing_document
    create_document "changes.txt"

    get '/changes.txt/edit'
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_edit_content
    post '/changes.txt', content: "new content"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
end