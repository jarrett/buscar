module Buscar
	module Helpers
		# Accepts an instance of Buscar::Index, which will tell it the total number of pages, the current page, and the number of records per page.
		# Accepts a block, which is yielded each page number and must return a URL to that page.
		def page_links(index)
			unless block_given?
				raise ArgumentError, 'page_links requires a block.'
			end
			total_pages = index.page_count
			if total_pages > 1
				current_page = index.page + 1
				content_tag('ul', 'class' => 'pagination') do
					lis = ''
					min_page = current_page - 2
					min_page = 1 if min_page < 1
					max_page = current_page + 2
					max_page = total_pages if max_page > total_pages
					if current_page > 1
						lis << content_tag('li', link_to('&laquo; Back'.html_safe, yield(current_page - 1)))
					end
					if min_page > 1
						lis << content_tag('li', link_to('1', yield(1)))
					end
					if min_page > 2
						lis << content_tag('li', '...')
					end
					(min_page..max_page).each do |page|
						lis << content_tag('li') do
							if current_page.to_i == page
								page.to_s
							else
								link_to page, yield(page)
							end
						end
					end
					if max_page < total_pages - 1
						lis << content_tag('li', '...')
					end
					if max_page < total_pages				
						lis << content_tag('li', link_to(total_pages, yield(total_pages)))
					
					end
					if current_page < total_pages
						lis << content_tag('li', link_to('Next &raquo;'.html_safe, yield(current_page + 1)))
					end
					lis.html_safe
				end.html_safe
			else
				nil
			end
		end
		
		def buscar_index_menu(index, type, options)
			options.reverse_merge! :link_to_current => true
			content_tag('ul', :class => "#{type}_menu") do
				choices = ''
				index.send("#{type}_param_options").each do |param, label_str|
					choices << content_tag('li') do
						label_str = param.to_s.humanize if label_str.nil?
						is_selected = index.send("#{type}_param").to_s == param.to_s
						if is_selected and !options[:link_to_current]
							('<span class="selected">' + label_str + '</span>').html_safe
						else
							link_options = is_selected ? {:class => 'selected'} : {}
							link_to label_str, yield(param), link_options
						end
					end
				end
				choices.html_safe
			end.html_safe
		end
		
		def filter_menu(index, options = {}, &block)
			buscar_index_menu(index, 'filter', options, &block)
		end
		
		def sort_menu(index, options = {}, &block)
			buscar_index_menu(index, 'sort', options, &block)
		end
	end
end