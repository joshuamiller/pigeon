require 'camping'
require 'camping/session'
require 'haml'
require 'digest/sha1'

Camping.goes :Pigeon

module Pigeon 
  include Camping::Session
  def state_secret; "microblogical"; end
  def posts_per_page; 5; end
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
      @page = @input['page'] ? @input['page'].to_i : 1
      @posts = Post.find(:all, :limit => posts_per_page, :offset => ((@page - 1) * posts_per_page), :order => "created_at DESC")
      @previous_page = (@page == 1) ? nil : @page - 1
      @next_page = (Post.count - (@page * posts_per_page)) > 0 ? @page + 1 : nil
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
    if @user
      h2 "Administer Site"
      h3 { a "New Post", :href => R(New) } 
      h3 { a "Log Out", :href => R(Logout) }
    end
    for post in @posts
      h2 post.title
      h3 "Posted #{post.created_at.strftime("%A %B %d, %Y")}"
      p post.body
      p { (a "Delete Post", :href => R(Delete, post.id)) } if @user
    end
    p { a "Previous Page", :href => "/?page=#{@previous_page}" } if @previous_page
    p { a "Next Page", :href => "/?page=#{@next_page}" } if @next_page
    unless @user
      a "Log In Admin", :href => R(Login)
    end
  end

  def new
    h1 "Create New Post"
    form :action => 'create', :method => 'post' do
      p do
        label "Title", :for => 'title'
        input :name => 'title', :type => 'text', :size => 30
      end
      p do
        label "Body", :for => 'body'
        textarea :name => 'body', :rows => 15, :cols => 50
      end
      p do input :type => 'submit', :value => 'Submit' end
    end
  end

  def show
    h2 @post.title
    h3 "Posted #{post.created_at.strftime("%A %B %d, %Y")}"
    p @post.body
  end

  def login
    h3 "Please Log In"
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
