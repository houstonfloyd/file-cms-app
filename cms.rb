require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'pry'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'
require 'bcrypt'

configure do
  enable :sessions
  set :session_secret, "secret"
end

helpers do
  def sort_files(files)
    files.sort
  end
end

def data_path
  if ENV['RACK_ENV'] == 'test'
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

get '/' do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_content(file)
  content = File.read(file)
  case File.extname(file)
  when '.txt'
    headers["Content-Type"] = "text/plain"
    content
  when '.md'
    erb render_markdown(content)
  end
end

def name_error(file_name)
  if file_name.strip.empty?
    "#A name is required."
  end
end

def load_user_credentials
  credentials_path = if ENV["RANK_ENV"] == 'test'
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end

  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    crypt_password == password
  else
    false
  end
end

def invalid_user
  credentials = load_user_credentials
  username = session[:username]

  credentials.key?(username) && credentials[username] == params[:password]
end

def require_signed_in_user
  if invalid_user
    session[:message] = "You must be signed in to do that."
    redirect '/'
  end
end

get '/new' do
  require_signed_in_user

  erb :new_file
end

get '/users/signin' do

  erb :signin
end

post '/users/signin' do
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = params[:username]
    session[:message] = "Welcome!"
    redirect '/'
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :signin
  end
end

post '/users/signout' do
  session[:username] = nil
  session[:message] = "You have been signed out."
  redirect '/'
end

post '/' do
  require_signed_in_user
  file_name = params[:file_name]
  error = name_error(file_name)

  file_name = file_name + '.txt' if !File.basename(file_name).include? '.'
  file_path = File.join(data_path, file_name)

  if error
    session[:message] = error
    status 422
    erb :new_file
  else
    File.write(file_path, '')
    session[:message] = "#{params[:file_name]} has been created."
    redirect '/'
  end
end

get '/:file_name' do
  file_name = params[:file_name]
  file_path = File.join(data_path, file_name)

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{file_name} does not exist."
    redirect "/"
  end
end

get '/:file_name/edit' do
  require_signed_in_user
  @file_name = params[:file_name]
  file_path = File.join(data_path, @file_name)
  @content = File.read(file_path)

  erb :edit_file
end

post '/:file_name/delete' do
  require_signed_in_user

  @file_name = params[:file_name]
  file_path = File.join(data_path, @file_name)

  File.delete(file_path)
  session[:message] = "#{params[:file_name]} has been deleted."
  redirect '/'
end

post "/:file_name" do
  require_signed_in_user

  file_path = File.join(data_path, params[:file_name])
  content = params[:content]

  File.write(file_path, content)
  session[:message] = "#{params[:file_name]} has been updated."
  redirect '/'
end