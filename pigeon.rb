require 'camping'
require 'camping/session'
require 'haml'

Camping.goes :Pigeon

module Pigeon 
  include Camping::Session
  def state_secret; "microblogical"; end
end

def Pigeon.create
  Pigeon::Models.create_schema
end

module Pigeon::Models
  class Post < Base; end
  class User < Base
    def self.authenticate(username, password)
      if user = User.find_by_username(username)
        expected_password = encrypted_password(password, user.salt)
        user = nil unless user.hashed_password == expected_password
      end
      user
    end
    
    def password=(pwd)
      return if pwd.blank?
      create_new_salt
      self.hashed_password = User.encrypted_password(pwd, self.salt)
    end
    
    private
    
    def self.encrypted_password(password, salt)
      string_to_hash = password + "microblogical" + salt
      Digest::SHA1.hexdigest(string_to_hash)
    end
    
    def create_new_salt
      self.salt = self.object_id.to_s + rand.to_s
    end
  end

  class CreatePigeon < V 0.1
    def self.up
      create_table :pigeon_posts, :force => true do |t|
        t.string :title
        t.string :body
        t.timestamps
      end
      create_table :pigeon_users, :force => true do |t|
        t.string :username
        t.string :salt
        t.string :hashed_password
      end
    end
  end

  class SetupUsers < V 0.2
    def self.up
      User.create(:username => "josh", :password => "josh")
    end
  end

end

module Pigeon::Controllers
  class Index < R '/'
    def get
      @posts = Post.find :all
      @user = @state.user
      render :index
    end
  end
  class New < R '/posts/new'
    def get
      if @state.user 
        render :new
      else
        redirect Login
      end
    end
  end
  class Create < R '/posts/create'
    def get; redirect New; end
    def post
      if @state.user
        Post.create(:title => @input['title'], :body => @input['body'])
        redirect Index
      else
        redirect Login
      end
    end
  end
  class Show < R '/posts/(\d+)'
    def get(id)
      @post = Post.find(id)
      render :show
    end
  end
  class Delete < R '/posts/delete/(\d+)'
    def get(id)
      if @state.user
        @post = Post.find(id)
        @post.destroy
      end
      redirect Index
    end
  end
  class Login < R '/login'
    def get; render :login; end
    def post
      if user = User.authenticate(@input['username'], @input['password'])
        @state.user = user
        redirect Index
      else
        redirect Login
      end
    end
  end
  class Logout < R '/logout'
    def get
      @state.user = nil
      redirect Index
    end
  end
end

module Pigeon::Views
  def layout
    Haml::Engine.new(File.read("layout.haml")).render self do yield end
  end

  def index
    for post in @posts
      h2 post.title
      h3 post.created_at
      p post.body
      (a "Delete Post", :href => R(Delete, post.id)) if @user
    end
    if @user
      a "New Post", :href => R(New)
      a "Log Out", :href => R(Logout)
    else
      a "Log In Admin", :href => R(Login)
    end
  end

  def new
    form :action => 'create', :method => 'post' do
      p do
        label "Title", :for => 'title'
        input :name => 'title', :type => 'text'
      end
      p do
        label "Body", :for => 'body'
        input :name => 'body', :type => 'textarea'
      end
      p do input :type => 'submit' end
    end
  end

  def show
    h1 @post.title
    p @post.body
  end

  def login
    h1 @user
    form :action => 'login', :method => 'post' do
      p do
        label "Username", :for => 'username'
        input :name => 'username', :type => 'text'
      end
      p do
        label "Password", :for => 'password'
        input :name => 'password', :type => 'password'
      end
      p do input :type => 'submit', :value => "Log In" end
    end
  end

end
