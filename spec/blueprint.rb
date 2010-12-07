require 'machinist/active_record'
require 'sham'
require 'faker'

Sham.define do
	city { Faker::Address.city }
	business { Faker::Company.name }
	tag { Faker::Lorem.words(1) }
end

City.blueprint do
	name { Sham.city }
end

Business.blueprint do
	city { City.make }
	name { Sham.business }
	active true
end

Tag.blueprint do
	name { Sham.tag }
	published true
end

Tagging.blueprint do
	business { Business.make }
	tag { Tag.make }
end

def tag_business(business, tag_name)
	tag = Tag.find_by_name(tag_name) || Tag.make(:name => tag_name)
	Tagging.make(:tag => tag, :business => business)
end