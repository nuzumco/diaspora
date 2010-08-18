class Person
  include MongoMapper::Document
  include ROXML

  xml_accessor :_id
  xml_accessor :email
  xml_accessor :url
  xml_accessor :profile, :as => Profile
  
  
  key :email, String, :unique => true
  key :url, String

  key :serialized_key, String 


  key :owner_id, ObjectId
  key :user_refs, Integer, :default => 0 

  belongs_to :owner, :class_name => 'User'
  one :profile, :class_name => 'Profile'

  many :albums, :class_name => 'Album', :foreign_key => :person_id


  timestamps!

  before_destroy :remove_all_traces
  before_validation :clean_url
  validates_presence_of :email, :url, :profile, :serialized_key 
  validates_format_of :url, :with =>
     /^(https?):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*(\.[a-z]{2,5})?(:[0-9]{1,5})?(\/.*)?$/ix
  
  
  def self.search(query)
    Person.all('$where' => "function() { return this.email.match(/^#{query}/i) ||
               this.profile.first_name.match(/^#{query}/i) ||
               this.profile.last_name.match(/^#{query}/i); }")
  end

  def real_name
    "#{profile.first_name.to_s} #{profile.last_name.to_s}"
  end

  def encryption_key
    OpenSSL::PKey::RSA.new( serialized_key )
  end

  def encryption_key= new_key
    raise TypeError unless new_key.class == OpenSSL::PKey::RSA
    serialized_key = new_key.export
  end

  def export_key
    encryption_key.public_key.export
  end

  ##profile
  def update_profile(params)
    if self.update_attributes(params)
      self.profile.notify_people!
      true
    else
      false
    end
  end

  def owns?(post)
    self.id == post.person.id
  end

  def receive_url
    "#{self.url}receive/users/#{self.id}/"
  end

  def self.by_webfinger( identifier )
     Person.first(:email => identifier.gsub('acct:', ''))
  end
  
  def remote?
    owner.nil?
  end

  protected
  def clean_url
    self.url ||= "http://localhost:3000/" if self.class == User
    if self.url
      self.url = 'http://' + self.url unless self.url.match('http://' || 'https://')
      self.url = self.url + '/' if self.url[-1,1] != '/'
    end
  end
  private
  def remove_all_traces
    Post.all(:person_id => id).each{|p| p.delete}
    Album.all(:person_id => id).each{|p| p.delete}
  end
 end
