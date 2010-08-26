module Buscar
	module IndexMatchers
		class IncludeTag
			def initialize(name)
				@name = name
			end
			
			def matches?(index)
				@index = index
				!index.records.detect { |tag| tag.name == @name }.nil?
			end
			
			def failure_message
				"Expected records to include tag #{@name}. Got: [#{@index.records.collect(&:name).join(', ')}]"
			end
			
			def negative_failure_message
				"Expected records to exclude tag #{@name}. Got: [#{@index.records.collect(&:name).join(', ')}]"
			end
		end
		
		def include_tag(name)
			IncludeTag.new(name)
		end
		
		class SortTags
			def initialize(*names)
				@names = names
			end
			
			def matches?(index)
				@index = index
				return false unless index.records.length == @names.length
				index.records.collect(&:name) == @names
			end
			
			def failure_message
				"Expected tags to be sorted in this order: [#{@names.join(', ')}], but got: [#{@index.records.collect(&:name).join(', ')}]"
			end
			
			def negative_failure_message
				"Expected tags mot to be sorted in this order: [#{@names.join(', ')}]"
			end
		end
		
		def sort_tags(*names)
			SortTags.new(*names)
		end
	end
end