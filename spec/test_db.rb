require 'active_record'
#ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Base.establish_connection(
	:adapter => "sqlite3",
	:database => ":memory:"
)

ActiveRecord::Schema.define do
	create_table :cities, :force => true do |t|
		t.string :name, :null => false
	end
	
	create_table :businesses, :force => true do |t|
		t.integer :city_id, :null => false
		t.string :name, :null => false
		t.boolean :active, :null => false, :default => true
	end
	
	create_table :tags, :force => true do |t|
		t.string :name, :null => false
	end
	
	create_table :taggings, :force => true do |t|
		t.integer :business_id, :null => false
		t.integer :tag_id, :null => false
	end
end

class City < ActiveRecord::Base
	validates_presence_of :name
end

class Business < ActiveRecord::Base
	belongs_to :city
	has_many :taggings, :dependent => :destroy
	has_many :tags, :through => :taggings
	validates_presence_of :name, :city_id
end

class Tag < ActiveRecord::Base
	has_many :taggings, :dependent => :destroy
	has_many :businesses, :through => :taggings
	validates_presence_of :name
	
	def active_businesses_in_city(city)
		unless city.is_a?(City)
			raise(ArgumentError, "Expected City but got #{city.inspect}")
		end
		@active_businesss_by_city ||= {}
		@active_businesss_by_city[city.id] ||= businesses.select { |b| b.active and b.city_id == city.id }
	end
end

class Tagging < ActiveRecord::Base
	belongs_to :tag
	belongs_to :business
	validates_presence_of :business_id, :tag_id
end