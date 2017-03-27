require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'pry'
require 'tilt/erubis'
require 'redcarpet'

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
  @file_name = params[:file_name]
  file_path = File.join(data_path, @file_name)
  @content = File.read(file_path)

  erb :edit_file
end

post "/:file_name" do
  file_path = File.join(data_path, params[:file_name])
  content = params[:content]

  File.write(file_path, content)
  session[:message] = "#{params[:file_name]} has been updated."
  redirect '/'
end