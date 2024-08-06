class BirdsController < ApplicationController
  wrap_parameters format: []

  # POST /birds
  def create
    bird = Bird.create(bird_params)
    render json: bird, status: :created
  end

  # other controller actions here

  private
  # all methods below here are private

  def bird_params
    params.permit(:name, :species)
  end
end
