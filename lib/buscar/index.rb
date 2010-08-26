module Buscar
	class Index
		include Enumerable
		
		# Views can call this method to iterate over the current page's records. Uses
		# the value returned by #page, which in turn uses the value of @params[:page]
		def each
			records_on_page(page).each do |record|
				yield record
			end
		end
		
		def empty?
			@records.empty?
		end
		
		def filter_param
			@params[:filter] || (respond_to?(:default_filter_option) ? default_filter_option : 'none')
		end
		
		def filter_param_options
			filter_options.collect(&:first)
		end
		
		def self.generate(*args)
			index = new(*args)
			index.generate!
			index
		end
		
		def generate!
			unless respond_to?(:finder)
				raise 'Subclasses of Index must define #finder, which must return something that responds to #find. For example, #finder may return an ActiveRecord::Base subclass.'
			end
			include_clause = respond_to?(:include) ? include : nil
			@records = finder.find(:all, :conditions => conditions, :include => include_clause, :order => order)
			if select_proc
				@records = @records.select(&select_proc)
			end
			if sort_proc
				@records = @records.sort_by(&sort_proc)
			end
		end
		
		def initialize(params = {})
			@params = params
		end
		
		def length
			@records.length
		end
		
		def optional_params(*keys)
			keys.inject({}) do |hash, key|
				unless @params[key].blank?
					hash[key] = @params[key]
				end
				hash
			end
		end
		
		# The current page, as determined by @params[:page]. Since we want the user to see the page array as one-based,
		# but we use zero-based indices internally, we subtract one from the page number.
		#
		# Thus, the return value is a zero-based offset.
		def page
			(@params[:page] || @params['page'] || 1).to_i - 1
		end
		
		def page_count
			(@records.length.to_f / records_per_page).ceil
		end
		
		attr_reader :params
		
		# page_num is zero-based for this method.
		def records_on_page(page_num)
			if paginate?
				@records.slice((page_num) * records_per_page, records_per_page)
			else
				@records
			end
		end
		
		def sort_param
			@params[:sort] || (respond_to?(:default_sort_option) ? default_sort_option : 'none')
		end
		
		def sort_param_options
			sort_options.collect(&:first)
		end
		
		attr_reader :records
		
		protected
		
		# Returns the filter option matching @params[:filter], or else nil
		def chosen_filter_option
			if respond_to?(:filter_options)
				if @params.has_key?(:filter) and @params[:filter] != 'none'
					filter_options.assoc(@params[:filter].to_s)[1]
				elsif respond_to?(:default_filter_option)
					filter_options.assoc(default_filter_option.to_s)[1]
				else
					nil
				end
			else
				nil
			end
		end
		
		# Returns the sort option matching @params[:sort], or else nil
		def chosen_sort_option
			if respond_to?(:sort_options)
				if @params.has_key?(:sort) and @params[:sort] != 'none'
					sort_options.assoc(@params[:sort].to_s)[1]
				elsif respond_to?(:default_sort_option)
					sort_options.assoc(default_sort_option.to_s)[1]
				else
					nil
				end
			else
				nil
			end
		end
		
		def conditions
			filter = chosen_filter_option
			filter.is_a?(Proc) ? nil : filter # Anything other than a Proc (including nil) should be passed to :conditions
		end
		
		def order
			sort = chosen_sort_option
			(sort.is_a?(String) or sort.is_a?(Symbol)) ? sort : nil
		end
		
		def paginate?
			true
		end
		
		def records_per_page
			50
		end
		
		def select_proc
			filter = chosen_filter_option
			filter.is_a?(Proc) ? filter : nil
		end
		
		def sort_proc
			sort = chosen_sort_option
			sort.is_a?(Proc) ? sort : nil
		end
	end
end