require 'spec_helper'
require 'active_support'
require 'action_view'
require 'action_view/base' # For the NonConcattingString class
require 'action_view/template/handlers/erb' # For the OutputBuffer class
require 'webrat'

describe Buscar::Helpers do
	include Webrat::Matchers
	include ActionView::Helpers
	include Buscar::Helpers
	
	# This magic code allows certain Rails helpers to work without loading the whole Rails environment.
	# I'm assuming that CaptureHelper uses it to store the captured output.
	attr_accessor :output_buffer
	
	describe '#filter_menu' do
		before :each do
			@index = mock(:filter_param_options => [['breakfast', 'Breakfast Time'], ['lunch'], ['dinner']], :filter_param => 'lunch')
		end
		
		it 'yields each possible filter param' do
			yielded = []
			filter_menu(@index) do |filter_param|
				yielded << filter_param
				''
			end
			yielded.should == ['breakfast', 'lunch', 'dinner']
		end
		
		it 'prints a link for each option, using the URL returned by the block and the humanized param or the overridden label as the text' do
			html = filter_menu(@index) do |filter_param|
				"http://test.host/#{filter_param}"
			end
			html.should include('<a href="http://test.host/breakfast">Breakfast Time</a>')
			html.should include('<a href="http://test.host/lunch">Lunch</a>')
			html.should include('<a href="http://test.host/dinner">Dinner</a>')
		end
	end
	
	describe '#sort_menu' do
		before :each do
			@index = mock(:sort_param_options => [['name'], ['dishes', 'Number of Dishes'], ['reviews']], :sort_param => 'dishes')
		end
		
		it 'yields each possible sort param' do
			yielded = []
			sort_menu(@index) do |sort_param|
				yielded << sort_param
				''
			end
			yielded.should == ['name', 'dishes', 'reviews']
		end
		
		it 'prints a link for each option, using the URL returned by the block and the humanized param or the overridden label as the text' do
			html = sort_menu(@index) do |sort_param, filter_param|
				"http://test.host/#{sort_param}"
			end
			html.should include('<a href="http://test.host/name">Name</a>')
			html.should include('<a href="http://test.host/dishes">Number of Dishes</a>')
			html.should include('<a href="http://test.host/reviews">Reviews</a>')
		end
	end
	
	describe '#page_links' do
		before :each do
			@index = mock(:page_count => 3, :page => 1) # Index#page returns a zero-based offset. The helper must convert to one-based.
		end
		
		it 'determines the correct, 1-based current page' do
			page_links(@index) { |page| "/pages/#{page}" }.should have_selector('ul') do |ul|
				ul.should have_selector('li') do |one|
					one.should have_selector('a', 'href' => '/pages/1', :content => '1')
				end
				ul.should have_selector('li', :content => '2')
				ul.should have_selector('li') do |three|
					three.should have_selector('a', 'href' => '/pages/3', :content => '3')
				end
			end
		end
	end	
end