module Buscar
	if defined? Rails::Railtie
		require 'rails'
		class Railtie < Rails::Railtie
			initializer 'buscar.insert_into_action_view' do
				ActiveSupport.on_load :action_view do
					Buscar::Railtie.insert
				end
			end
		end
	end

	class Railtie
		def self.insert
			ActionView::Base.send(:include, Buscar::Helpers)
		end
	end
end
