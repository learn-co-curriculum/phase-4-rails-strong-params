require 'byebug'

class BirdWatcher
  attr_accessor :name, :email, :bio, :favorite_species, :admin

  def initialize(args)
    @name = args[:name]
    @email = args[:email]
    @bio = args[:bio]
    @favorite_species = args[:favorite_species]
    @admin = args[:admin]
  end
end

params = {
  name: "Reggie",
  email: "birdman5000@gmail.com",
  favorite_species: "Crow",
  bio: "Just a bird-loving guy",
  admin: true
}

reg = BirdWatcher.new(params)

byebug
""
