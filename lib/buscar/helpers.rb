module Buscar
	module Helpers
		def filter_menu(index)
			content_tag('ul', :class => 'filter_menu') do
				choices = ''
				index.filter_param_options.each do |param|
					choices << content_tag('li') do
						if index.filter_param.to_s == param.to_s
							'<span class="selected">' + param.to_s.humanize + '</span>'
						else
							link_to param.to_s.humanize, yield(param)
						end
					end
				end
				choices
			end
		end
		
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
						lis << content_tag('li', link_to('&laquo; Back', yield(current_page - 1)))
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
						lis << content_tag('li', link_to('Next &raquo;', yield(current_page + 1)))
					end
					lis
				end
			else
				nil
			end
		end
		
		def sort_menu(index)
			 content_tag('ul', :class => 'sort_menu') do
				choices = ''
				index.sort_param_options.each do |param|
					choices << content_tag('li') do
						if index.sort_param.to_s == param.to_s
							'<span class="selected">' + param.to_s.humanize + '</span>'
						else
							link_to param.to_s.humanize, yield(param)
						end
					end
				end
				choices
			end
		end
	end
end