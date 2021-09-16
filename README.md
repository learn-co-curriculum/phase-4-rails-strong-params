# Strong Params and Mass Assignment

## Learning Goals

- Explain the benefits and dangers of mass assignment
- Use `params.permit` to allow specific params

## Setup

To get set up, run:

```console
$ bundle install
$ rails db:migrate db:seed
```

This will download all the dependencies for our app and set up the database.

## Video Walkthrough

<iframe width="560" height="315" src="https://www.youtube.com/embed/2NSsNs-sanI?rel=0&amp;showinfo=0" frameborder="0" allowfullscreen></iframe>

## Revisiting The Create Action

In the previous lesson, we used the `params` hash to access data from the body
of a request, and create a new bird:

```rb
Bird.create(name: params[:name], species: params[:species])
```

Since our model only has two attributes, this code looks fairly reasonable. But
imagine we were building a new model, `BirdWatcher`, representing the users in
our application, that has more attributes:

```rb
BirdWatcher.create(
  name: params[:name],
  email: params[:email],
  profile_image: params[:profile_image],
  favorite_species: params[:favorite_species],
  admin: params[:admin]
)
```

While this approach for creating a new `BirdWatcher` would work, it feels like a
lot of extra work to type `attribute: params[:attribute]` for every single
attribute we're using! Since the `.create` method expects a hash of key-value
pairs, and `params` is a hash of key-value pairs, it would be much nicer to be
able to just pass in the entire `params` hash and call it a day:

```rb
BirdWatcher.create(params)
```

However, doing so would open us up to some surprising security vulnerabilities,
so Rails would actually prevent that code from working! Let's explore why, and
see an alternate approach to working with `params`.

## What Is Mass Assignment?

Let's take a step back from Rails for the moment, and think back to
Object-Oriented Ruby. We could design a `BirdWatcher` class of our own, without
Active Record, like so:

```rb
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
```

Now, we can pass in one hash when creating a new `BirdWatcher`, just like we
would when creating an object with Active Record:

```rb
BirdWatcher.new(
  name: "Reggie",
  email: "birdman5000@gmail.com",
  favorite_species: "Crow",
  bio: "Just a bird-loving guy",
  admin: false
)
```

So far so good! Now, let's imagine that instead of passing in that hash
directly, we're getting that hash of data from a user making a request to our
API to create a new account. Pretend this `params` hash is being created based
on a user making a request to our server:

```rb
params = {
  name: "Emma",
  email: "lady.von.birdbrain@yahoo.com",
  favorite_species: "Blue Jay",
  bio: "Always be birding",
  admin: true
}
```

Ideally, a user shouldn't be able to create their own account and give themself
`admin` privileges. But if we pass this entire hash of parameters to our
`#initialize` method, that's exactly what will happen:

```rb
BirdWatcher.new(params)
# => #<BirdWatcher:0x00007fa635094858 @name="Emma", ... @admin=true>
```

Active Record works similarly: it uses mass assignment to take a hash of
key-value pairs and assign them to attributes on our models. As a result,
passing in the entire `params` hash when creating a new record in our database
would open us up to the [mass assignment vulnerability][].

So how do we fix it?

## Strong Params

First, run `rails s` to start the server. Let's use Postman to create a new bird:

```txt
Route
-------
POST /birds

Headers
-------
Content-Type: application/json

Body
------
{
  "name": "Blue Jay",
  "species": "Cyanocitta cristata"
}
```

This will create a new `Bird` in our `BirdsController#create` action:

```rb
def create
  bird = Bird.create(name: params[:name], species: params[:species])
  render json: bird, status: :created
end
```

The approach above is a perfectly valid solution to the mass-assignment issue.
Since we are **explicitly** specifying which attributes we'd like our new bird
to be created with, there's no chance of a user updating an attribute other than
name or species.

Update the `create` method like so:

```rb
def create
  bird = Bird.create(params)
  render json: bird, status: :created
end
```

Then, make another request using Postman. We'll get back a
`500 - Internal Server Error` as a response, with an
`ActiveModel::ForbiddenAttributesError` as the exception.

This is thanks to Rails' built-in security protection against the
[mass assignment vulnerability][] in action. We can't just pass in the entire
params hash, since that would mean a malicious user could potentially update
attributes of our model that we don't want to give them access to.

What we can do instead is use [Strong Parameters][strong params] to **permit**
_only_ the parameters that we want to use:

```rb
def create
  bird = Bird.create(params.permit(:name, :species))
  render json: bird, status: :created
end
```

When we call `params.permit(:name, :species)`, this will return a new hash with
**only** the name and species keys. Rails will also mark this new hash as
`permitted`, which means we can safely use this new hash for mass assignment.

Try making that same request in Postman, but this time, add an `id` key to the
JSON in your request body. Now the bird is successfully created but, since the
`id` key was not allowed, only the `name` and `species` were used. The server
logs will verify this for us:

```txt
Started POST "/birds" for ::1 at 2021-05-03 07:45:33 -0400
   (0.1ms)  SELECT sqlite_version(*)
Processing by BirdsController#create as */*
  Parameters: {"name"=>"Blue Jay", "species"=>"Cyanocitta cristata", "id"=>99, "bird"=>{"id"=>99, "name"=>"Blue Jay", "species"=>"Cyanocitta cristata"}}
Unpermitted parameters: :id, :bird
  TRANSACTION (0.1ms)  begin transaction
  ↳ app/controllers/birds_controller.rb:12:in `create'
  Bird Create (0.8ms)  INSERT INTO "birds" ("name", "species", "created_at", "updated_at") VALUES (?, ?, ?, ?)  [["name", "Blue Jay"], ["species", "Cyanocitta cristata"], ["created_at", "2021-05-03 11:45:33.745635"], ["updated_at", "2021-05-03 11:45:33.745635"]]
  ↳ app/controllers/birds_controller.rb:12:in `create'
  TRANSACTION (1.3ms)  commit transaction
  ↳ app/controllers/birds_controller.rb:12:in `create'
Completed 201 Created in 22ms (Views: 2.5ms | ActiveRecord: 3.6ms | Allocations: 3803)
```

## Refactoring Params

In Rails controllers there's a strong convention among developers to create a
separate `private` method for strong params, like so:

```rb
class BirdsController < ApplicationController

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
```

This makes our `create` action a bit cleaner, and will give us the opportunity
to reuse this private method later in our `update` action.

You may also have noticed that even though the request body only has this data:

```json
{
  "name": "Blue Jay",
  "species": "Cyanocitta cristata"
}
```

Our params hash looks like this:

```rb
{
  "name"=>"Blue Jay",
  "species"=>"Cyanocitta cristata",
  "bird"=>{
    "name"=>"Blue Jay",
    "species"=>"Cyanocitta cristata"
  }
}
```

The reason for this is that Rails by default will
[wrap JSON parameters][wrap parameters] as a nested hash under a key based on
the name of the controller (in our case, `bird` since we're in a
`BirdsController`). This is the reason that in the Rails server log, even with
our strong params in place, you'll still see `Unpermitted parameters: :bird` for
our requests.

You can disable the wrap parameters feature in an individual controller:

```rb
class BirdsController < ApplicationController
  wrap_parameters format: []
end
```

You can also disable it for all controllers if you like, by going into the
`config/initializers/wrap_parameters.rb` file and updating it like so:

```rb
ActiveSupport.on_load(:action_controller) do
  wrap_parameters format: []
end
```

## Conclusion

In this lesson, we learned how we can use mass assignment to reduce the amount
of code we need to write to create a new instance of a model. We also learned
why using mass assignment can expose us to security vulnerabilities and how to
keep that from happening.

## Check For Understanding

Before you move on, make sure you can answer the following questions:

1. What is the mass assignment vulnerability?
2. What security precaution is built in to Rails to protect against this
   vulnerability?
3. What two approaches can we use to handle parameters safely?

## Resources

- [Rails Guides on Strong Params][strong params]

[strong params]: https://guides.rubyonrails.org/action_controller_overview.html#strong-parameters
[wrap parameters]: https://edgeguides.rubyonrails.org/action_controller_overview.html#json-parameters
[mass assignment vulnerability]: https://en.wikipedia.org/wiki/Mass_assignment_vulnerability
