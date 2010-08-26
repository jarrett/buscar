Buscar::Helpers
require 'test_db'
require 'blueprint'
require 'matchers'

describe Buscar::Index do
	include Buscar::IndexMatchers
	
	def setup_paginated_records
		@burgers   = Tag.make(:name => 'Burgers')
		@ethiopian = Tag.make(:name => 'Ethiopian')
		@french    = Tag.make(:name => 'French')
		@indian    = Tag.make(:name => 'Indian')
		@mexican   = Tag.make(:name => 'Mexican')
		@pizza     = Tag.make(:name => 'Pizza')
		@thai      = Tag.make(:name => 'Thai')
	end
	
	before :all do
		@chicago = City.make(:name => 'Chicago')
		@dc = City.make(:name => 'Washington')
	end
	
	before :each do
		Business.delete_all
		Tag.delete_all
		Tagging.delete_all
	end
	
	describe '#each' do
		it 'iterates over the results on the current page' do
			setup_paginated_records
			
			# Index mixes in enumerable, so calling to_a is an easy way
			# to test what's yielded by #each
			{
				1 => [@burgers, @ethiopian],
				2 => [@french, @indian],
				3 => [@mexican, @pizza],
				4 => [@thai]
			}.each do |page, tags|
				index = SimpleTagIndex.new(:page => page)
				index.stub(:records_per_page => 2)
				index.stub(:order => :name)
				index.generate!
				index.to_a.should == tags
			end
		end
		
		it 'iterates over all records if paginate? returns false' do
			setup_paginated_records
			
			index = SimpleTagIndex.new
			index.stub(:records_per_page => 2)
			index.stub(:paginate? => false)
			index.generate!
			
			index.to_a.length.should == 7
		end
	end
	
	describe '#empty?' do
		it 'returns true if no records are found' do
			SimpleTagIndex.generate.empty?.should be_true
		end
		
		it 'returns false if records are found' do
			Tag.make
			SimpleTagIndex.generate.empty?.should be_false
		end
	end
	
	describe '#filter_param' do
		it 'returns whatever was given in the params' do
			SimpleTagIndex.new(:filter => 'long_names').filter_param.should == 'long_names'
		end
		
		it 'returns "none" if nothing was given and default_filter_option is undefined' do
			SimpleTagIndex.new.filter_param.should == 'none'
		end
		
		it 'returns the default if nothing was given and default_filter_option is defined' do
			index = SimpleTagIndex.new
			index.stub(:default_filter_option => 'long_names')
			index.filter_param.should == 'long_names'
		end
	end
	
	describe '#filter_param_options' do
		it 'returns an array of all the possible filter_options' do
			AutoSwitchingTagIndex.new.filter_param_options.should == ['short_name', 'long_name']
		end
		
		it 'raises if sort_options is not defined' do
			lambda { SimpleTagIndex.new.filter_param_options }.should raise_error
		end
	end
	
	describe '.generate' do
		it 'returns an instance of Index' do
			TagIndex.generate(@chicago).should be_an(Buscar::Index)
		end
		
		it 'filters by select_proc' do
			chi_ethio = Business.make(:city => @chicago, :name => 'Ras Dashen')
			chi_pizza = Business.make(:city => @chicago, :active => false, :name => 'Medici')
			dc_pizza  = Business.make(:city => @dc, :name => "Alberto's")
			
			tag_business(chi_ethio, 'Ethiopian')
			tag_business(chi_pizza, 'Pizza')
			tag_business(dc_pizza,  'Pizza')
			
			index = TagIndex.generate(@chicago)
			
			index.should     include_tag('Ethiopian')
			index.should_not include_tag('Pizza')
		end
		
		it 'filters by conditions' do
			ethio = Business.make(:city => @chicago)
			pizza = Business.make(:city => @chicago)
			
			tag_business(ethio, 'Ethiopian')
			tag_business(pizza, 'Pizza')
			
			index = TagIndex.generate(@chicago, :name => 'Ethiopian')
			
			index.should     include_tag('Ethiopian')
			index.should_not include_tag('Pizza')
		end
		
		it 'sorts by sort_proc' do
			# 1 Pizza place, 2 Ethiopian places, 3 Thai places
			tag_business(Business.make(:city => @chicago), 'Pizza')
			2.times { tag_business(Business.make(:city => @chicago), 'Ethiopian') }
			3.times { tag_business(Business.make(:city => @chicago), 'Thai') }
			
			index = TagIndex.generate(@chicago, :sort => 'businesses')
			
			# Descending order by number of businesses
			index.should sort_tags('Thai', 'Ethiopian', 'Pizza')
		end
		
		it 'sorts by order' do
			tag_business(Business.make(:city => @chicago), 'Pizza')
			tag_business(Business.make(:city => @chicago), 'Ethiopian')
			tag_business(Business.make(:city => @chicago), 'Vegetarian')
			tag_business(Business.make(:city => @chicago), 'Raw')
			
			index = TagIndex.generate(@chicago, :sort => 'name')
			
			index.should sort_tags('Ethiopian', 'Pizza', 'Raw', 'Vegetarian')
		end
		
		it 'uses include for eager loading' do
			Tag.should_receive(:find).with(:all, hash_including(:include => :businesses)).and_return([])
			TagIndex.generate(@chicago)
		end
		
		it 'filters with a proc according to filter_options and params[:filter]' do
			ethiopian = Tag.make(:name => 'Ethiopian')
			raw = Tag.make(:name => 'Raw')
			
			index = AutoSwitchingTagIndex.generate(:filter => 'long_name')
			
			index.records.should == [ethiopian]
		end
		
		it 'filters with an AR conditionaccording to filter_options and params[:filter]' do
			ethiopian = Tag.make(:name => 'Ethiopian')
			raw = Tag.make(:name => 'Raw')
			
			index = AutoSwitchingTagIndex.generate(:filter => 'short_name')
			
			index.records.should == [raw]
		end
		
		it 'sorts with a proc according to sort_options and params[:sort]' do
			# 1 Pizza place, 2 Ethiopian places, 3 Thai places
			tag_business(Business.make, 'Pizza')
			2.times { tag_business(Business.make, 'Ethiopian') }
			3.times { tag_business(Business.make, 'Thai') }
			
			index = AutoSwitchingTagIndex.generate(:sort => 'businesses')
			
			# Descending order by number of businesses
			index.should sort_tags('Thai', 'Ethiopian', 'Pizza')
		end
		
		it 'sorts with an AR order according to sort_options and params[:sort]' do
			pizza = Tag.make(:name => 'Pizza')
			raw = Tag.make(:name => 'Raw')
			ethiopian = Tag.make(:name => 'Ethiopian')
			
			index = AutoSwitchingTagIndex.generate(:sort => 'name')
			
			index.should sort_tags('Ethiopian', 'Pizza', 'Raw')
		end
		
		it 'uses default_sort_option' do
			pizza = Tag.make(:name => 'Pizza')
			raw = Tag.make(:name => 'Raw')
			ethiopian = Tag.make(:name => 'Ethiopian')
			
			index = AutoSwitchingTagIndex.new
			index.stub(:default_sort_option => :name)
			index.generate!
			
			index.should sort_tags('Ethiopian', 'Pizza', 'Raw')
		end
		
		it 'uses default_filter_option' do
			ethiopian = Tag.make(:name => 'Ethiopian')
			raw = Tag.make(:name => 'Raw')
			
			index = AutoSwitchingTagIndex.new
			index.stub(:default_filter_option => :short_name)
			index.generate!
			
			index.records.should == [raw]
		end
		
		it 'does not require subclasses to define anything other than #finder' do
			SimpleTagIndex.generate
		end
	end	
	
	describe '#length' do
		it 'returns the number of records' do
			3.times { Tag.make }
			SimpleTagIndex.generate.length.should == 3
		end
	end
	
	describe '#optional_params' do
		it 'accepts param keys and returns a hash of all the matching params that are defined' do
			SimpleTagIndex.new('name' => 'Jarrett', 'age' => '23', 'location' => 'chicago').optional_params('name', 'location').should == {'name' => 'Jarrett', 'location' => 'chicago'}
		end
	end
	
	describe '#page' do
		it 'returns the current zero-based page number, as determined by params, or defaults to 0' do
			SimpleTagIndex.new(:page => '5').page.should == 4
		end
	end
	
	describe '#page_count' do
		it 'returns the number of pages, taking into account records_per_page and the total number of records' do
			setup_paginated_records
			
			index = SimpleTagIndex.new
			index.stub(:records_per_page => 2)
			index.generate!
			
			index.page_count.should == 4
		end
	end
	
	describe '#params' do
		it 'returns @params' do
			index = SimpleTagIndex.new('foo' => 'bar')
			index.params.should == {'foo' => 'bar'}
		end
	end
	
	describe '#records_on_page' do
		it 'paginates the results using records_per_page' do
			setup_paginated_records
			
			index = SimpleTagIndex.new
			index.stub(:records_per_page => 2)
			index.stub(:order => :name)
			index.generate!
				
			index.records_on_page(0).should == [@burgers, @ethiopian]
			index.records_on_page(1).should == [@french, @indian]
			index.records_on_page(2).should == [@mexican, @pizza]
			index.records_on_page(3).should == [@thai]
		end
		
		it 'does not paginate if paginate? returns false' do
			setup_paginated_records
			
			index = SimpleTagIndex.new
			index.stub(:records_per_page => 2)
			index.stub(:paginate? => false)
			index.generate!
			
			index.records_on_page(0).length.should == 7
		end
	end
	
	describe '#sort_param' do
		it 'returns whatever was given in the params' do
			SimpleTagIndex.new(:sort => 'name').sort_param.should == 'name'
		end
		
		it 'returns "none" if nothing was given and default_sort_option is undefined' do
			SimpleTagIndex.new.sort_param.should == 'none'
		end
		
		it 'returns the default if nothing was given and default_sort_option is defined' do
			index = SimpleTagIndex.new
			index.stub(:default_sort_option => 'name')
			index.sort_param.should == 'name'
		end
	end
	
	describe '#sort_param_options' do
		it 'returns an array of all the possible sort_options' do
			AutoSwitchingTagIndex.new.sort_param_options.should == ['name', 'businesses']
		end
		
		it 'raises if sort_options is not defined' do
			lambda { SimpleTagIndex.new.sort_param_options }.should raise_error
		end
	end
end

class TagIndex < Buscar::Index
	def conditions
		@params.has_key?(:name) ? {:name => @params[:name]} : nil
	end
	
	def initialize(city, params = {})
		@city = city
		@params = params
	end
	
	def include
		:businesses
	end
	
	def finder
		Tag
	end
	
	def order
		@params[:sort].to_s == 'name' ? :name : nil
	end
	
	def records_per_page
		@params[:records_per_page] || 50
	end
	
	def select_proc
		lambda do |tag|
			!tag.active_businesses_in_city(@city).empty?
		end
	end
	
	def sort_proc
		if @params[:sort].to_s == 'businesses'
			lambda { |tag| -1 * tag.active_businesses_in_city(@city).length }
		else
			nil
		end
	end
end

class SimpleTagIndex < Buscar::Index
	def finder
		Tag
	end
end

class AutoSwitchingTagIndex < Buscar::Index
	def finder
		Tag
	end
	
	# Must return a hash. Keys correspond to possible values of params[:sort].
	# Values can be a string, a symbol, or a Proc. If a Proc, it will be passed to #sort_by.
	# If a string or symbol, it will be passed to #find as the :order option.
	def sort_options
		[
			['name', 'name'], # Will be passed to :conditions
			['businesses', lambda { |tag| -1 * tag.businesses.length }]
		]
	end
	
	# Must return a hash. Keys correspond to possible values of params[:filter].
	# Values can be a Proc or anything accepted by ActiveRecord's :conditions clause.
	# If a Proc, it will be passed to #select. Otherwise, it will be passed to #find as
	# the :conditions option.
	def filter_options
		[
			# Silly, but illustrates the functionality
			['short_name', 'LENGTH(name) < 5'],
			['long_name', lambda { |tag| tag.name.length > 6 }]
		]
	end
end

# Just to make sure our example models are working properly. We could just mock this stuff out, but I
# feel much more comfortable using real models when the subject of the test is the model layer. I've
# seen some weird bugs related to the interaction between plugins and ActiveRecord which would NOT
# have been caught had AR been mocked.
describe Tag do
	before :each do
		City.delete_all
		Business.delete_all
		Tag.delete_all
		Tagging.delete_all
	end
	
	describe '#active_businesses_in_city' do
		it 'filters inactive businesses' do
			chicago = City.make
			active = Business.make(:city => chicago)
			inactive = Business.make(:city => chicago, :active => false)
			tag_business(active, 'Pizza')
			tag_business(inactive, 'Pizza')
			Tag.find_by_name('Pizza').active_businesses_in_city(chicago).should == [active]
		end
		
		it 'filters businesses in other cities' do
			chicago = City.make
			dc = City.make
			chi_pizza = Business.make(:city => chicago)
			dc_pizza = Business.make(:city => dc)
			tag_business(chi_pizza, 'Pizza')
			tag_business(dc_pizza, 'Pizza')
			Tag.find_by_name('Pizza').active_businesses_in_city(chicago).should == [chi_pizza]
		end
	end
end