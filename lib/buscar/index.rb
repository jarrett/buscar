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
		
		# Returns one of the following in descending order of preference:
		# - params[:filter]
		# - default_filter_option
		# - 'none'
		def filter_param
			@params[:filter] || (respond_to?(:default_filter_option, true) ? default_filter_option : 'none')
		end
		
		def filter_param_options
			filter_options.collect do |opt|
				arr = [opt[0]]
				arr << opt[2] if opt.length == 3
				arr
			end
		end
		
		def self.generate(*args)
			index = new(*args)
			index.generate!
			index
		end
		
		def generate!
			unless respond_to?(:finder, true)
				raise 'Subclasses of Index must define #finder, which must return something that responds to #find. For example, #finder may return an ActiveRecord::Base subclass.'
			end
			
			raise "Buscar::Index#conditions is deprecated. Name your method where_clause instead." if respond_to?(:conditions, true)
			raise "Buscar::Index#order is deprecated. Name your method order_clause instead." if respond_to?(:order, true)
			raise "Buscar::Index#include_clause is deprecated. Name your method includes_clause instead." if respond_to?(:include, true)
			
			@records = finder.scoped # Get the bare relation object in case none of the modifiers are used
			# Use each AR query modifier other than #where and #order if applicable
			%w(having select group limit offset joins includes lock readonly from).each do |meth|
				@records = @records.send(meth, send("#{meth}_clause".to_sym)) if respond_to?("#{meth}_clause".to_sym, true)
			end
			
			chained_filters = filter
			chained_filters = chain(chained_filters) unless chained_filters.is_a?(Chain) # filter might return a Chain or a single filtering rule. If it's a single one, we'll put it in an array.
			@filter_procs = chained_filters.select { |f| f.is_a?(Proc) } # Procs will be triggered by the first call to #records so as not to defeat lazy loading
			where_filters = chained_filters.select { |f| !f.is_a?(Proc) } # SQL filters can be used right away
			where_filters.each do |filt|
				@records = @records.where(filt)
			end
			
			sort_rule = sort
			# If sorting by a proc, do it on the first call to #records so as not to defeat lazy loading 
			if sort_rule.is_a?(Proc)
				@sort_proc = sort_rule
			else
				@records = @records.order(sort_rule)
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
		
		# Returns one of the following in descending order of preference:
		# - params[:sort]
		# - default_sort_option
		# - 'none'
		def sort_param
			@params[:sort] || (respond_to?(:default_sort_option, true) ? default_sort_option : 'none')
		end
		
		def sort_param_options
			sort_options.collect do |opt|
				arr = [opt[0]]
				arr << opt[2] if opt.length == 3
				arr
			end
		end
		
		def records
			unless @procs_called
				@filter_procs.each do |proc|
					@records = @records.select(&proc)
				end
				@records = @records.sort_by(&@sort_proc) if @sort_proc
				@procs_called = true
			end
			@records
		end
		
		private
		
		class Chain < Array; end
		
		def chain(*elements)
			Chain.new(elements)
		end
		
		# Return something for #where, a Proc, or an array
		def filter
			if respond_to?(:filter_options, true) and (option = filter_options.assoc(filter_param))
				option[1]
			else
				nil
			end
		end
		
		def paginate?
			true
		end
		
		def records_per_page
			@params[:records_per_page] || 50
		end
		
		def sort
			if respond_to?(:sort_options, true) and (option = sort_options.assoc(sort_param))
				option[1]
			else
				nil
			end
		end
	end
end