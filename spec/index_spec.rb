require 'spec_helper'
require 'test_db'
require 'blueprint'
require 'matchers'

class TagIndex < Buscar::Index
	# You can give this any arity you want, but you must at some point initialize @params as a hash.
	# The superclass implementation takes one argument: the params hash.
	def initialize(city, params = {})
		@city = city
		@params = params
	end
	
	def finder
		Tag
	end
	
	# Must return a hash. Keys correspond to possible values of params[:sort].
	# Values can be a string, a symbol, or a Proc. If a Proc, it will be passed to #sort_by.
	# If a string or symbol, it will be passed to #order
	def sort_options
		[
			['name', 'name'], # Will be passed to #order
			['businesses', lambda { |tag| -1 * tag.active_businesses_in_city(@city).length }]
		]
	end
	
	# Optional to define. If not defined, the default sort order will be 'none',
	# which will probably mean that the records will be returned in order of creation.
	# (Unless some default ordering has been previously defined for the object returned by #finder.)
	# The string 'none' will in fact be passed to the #sort_menu helper and will appear in URLs
	# (assuming you use the helper).
	def default_sort_order
		'name'
	end
	
	# Must return a hash. Keys correspond to possible values of params[:filter].
	# Values can be a Proc or anything accepted by ActiveRecord's #where clause.
	# If a Proc, it will be passed to #select (the Enumerable method, not the Relation method.)
	# Otherwise, it will be passed to #where.
	def filter_options
		[
			# Silly, but illustrates the functionality
			['short_name', 'LENGTH(name) < 5'],
			['long_name', lambda { |tag| tag.name.length > 6 }]
		]
	end
	
	# Optional to define. If not defined, the default filter option will be 'none', which will, of course,
	# mean no filtering. The string 'none' will in fact be passed to the #filter_menu helper and will appear in URLs
	# (assuming you use the helper).
	def default_filter_option
		'short_name'
	end
	
	# Must return one of the following:
	# - Something that can be passed to #order.
	# - A proc for #select.
	# - An array where each element is one of the above. This will cause the filters to be chained, effectively ANDing them.
	#
	# If you're using automatic filter switching, you can implement this method to add
	# on some filtering that will always be applied, regardless of which option is selected.
	# To do that, return an array where one element is #super.
	# The implementation below illustrates just that:
	def filter
		[
			super, # Use automatic filter switching, i.e. use params[:filter] and #filter_options
			{:published => true}, # Only find published tags
			lambda { |tag| !tag.active_businesses_in_city(@city).empty? } # Only find tags with at least one published business
		]
	end

	# This could, if necessary, look at @params and intelligently decide what relationships to include.
	# In this case, though, we just return the same thing no matter what.
	def includes_clause
		:businesses
	end
	
	# This method is already defined in the superclass. By default, it looks at params[:records_per_page].
	# If that is undefined, it returns 50. One reason to override the method would be to return a different number
	# when params[:records_per_page] is undefined, as illustrated below. Or, you could make the method
	# ignore params[:records_per_page], thus preventing the user from choosing a value.
	def records_per_page
		@params[:records_per_page] || 25
	end
end

# This class implements #sort, and therefore does NOT use #sort_options
class TagIndexWithUnswitchableSorting < TagIndex
	# Must return one of the following:
	# - A string or symbol for #order
	# - A proc for #sort_by
	#
	# Unlike #filter, defining this method is NOT compatible with auto-switching.
	# This is because you cannot chain sorting--there can only be zero or one sort
	# orders in use for a given result set. So, only define this method if you
	# don't intend to use auto-switching for sorting. In this example, we always
	# sort the same way, but you could implement something dynamic.
	def sort
		'name'
	end
end

# This class demonstrates the bare minimum implementation of an Index subclass
class SimpleTagIndex < Buscar::Index
	def finder
		Tag
	end
end

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
				index.stub(:order_clause => :name)
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
			TagIndex.new.filter_param_options.should == ['short_name', 'long_name']
		end
		
		it 'raises if filter_options is not defined' do
			lambda { SimpleTagIndex.new.filter_param_options }.should raise_error
		end
	end
	
	describe '.generate' do
		it 'returns an instance of Index' do
			TagIndex.generate(@chicago).should be_an(Buscar::Index)
		end
		
		it 'uses #sort when #sort provides only a string'
		
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
			index.stub(:order_clause => :name)
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
			TagIndex.new.sort_param_options.should == ['name', 'businesses']
		end
		
		it 'raises if sort_options is not defined' do
			lambda { SimpleTagIndex.new.sort_param_options }.should raise_error
		end
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