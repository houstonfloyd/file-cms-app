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

#Requests and responses in Rack are associated with a large Hash of data 
#related to a request-response pair, called the "env" by Rack internally. 
#Some of the values in this hash are used by frameworks such as Sinatra 
#and Rails to access the path, parameters, and other attributes of the 
#request. The session implementation used by Sinatra is actually supplied 
#by Rack, and as a result the session object also lives in this Hash. 
#To access it within a test, we can use last_request.env. Note that the 
#last_request method is used here and not last_response.

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

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
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

  def test_document_not_found
    get "/notafile.ext"

    assert_equal 302, last_response.status
    assert_equal "notafile.ext does not exist.", session[:message]
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

    get '/changes.txt/edit', {}, admin_session
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_editing_document_signed_out
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_updating_document
    post "/changes.txt", content: "new content"

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end


  def test_view_new_document_form
    get "/new"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  # def test_create_new_document
  #   post "/", filename: "test.txt"
  #   assert_equal 302, last_response.status
  #   assert_equal "test.txt has been created.", session[:message]

  #   get "/"
  #   assert_includes last_response.body, "test.txt"
  # end

  def test_deleting_document
    create_document("test.txt")

    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "test.txt has been deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/test.txt")
  end

  def test_signin_form
    get '/users/signin'

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_signin
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "admin", session[:username]
    assert_equal "Welcome!", session[:message]

    get last_response['Location']
    assert_includes last_response.body, "Signed in as admin"
  end

 # def test_signin_with_bad_credentials
 #    post "/users/signin", username: "guest", password: "shhhh"
 #    assert_equal 422, last_response.status
 #    assert_nil, session[:username]
 #    assert_includes last_response.body, "Invalid credentials"
 #  end

  def test_signout
    get "/", {}, {"rack.session" => {username: "admin"} }
    assert_includes last_response.body, "Signed in as admin"

    post "/users/signout"
    get last_response["Location"]

    #assert_nil, session[:username]
    assert_includes last_response.body, "You have been signed out"
    assert_includes last_response.body, "Sign In"
  end

  # After adding the session method to access the last request's env, 
  #within a test, you can make assertions about the values 
  #within a session:

  # def test_sets_session_value
  #   get "/path_that_sets_session_value"
  #   assert_equal "expected value", session[:key]
  # end

  #If you need to go the other way (set a value in the session before 
  #a request is made), Rack::Test allows values for the Rack.env hash 
  #to be provided to calls to get and post within a test. So a simple 
  #request like this one:

  # def test_index
  #   get "/"
  # end

  #becomes this:

  def test_index_as_signed_in_user
    #two hash args: first is params (in this case empty), 2nd is
    #values to be added to the request's Rack.env hash
    get "/", {}, {"rack.session" => { username: "admin"} }
  end

  #Once values have been provided like this once, they will be remembered 
  #for all future calls to get or post within the same test, unless, 
  #of course, those values are modified by code within your application. 
  #This means that you can set values for the session in the first request 
  #made in a test and they will be retained until you remove them.
end