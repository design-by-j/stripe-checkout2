require "sinatra"
require "stripe"
require "sinatra/cross_origin"
require 'dotenv/load'
require "json"

configure do
  enable :cross_origin
end

options "*" do
  response.headers["Allow"] = "GET, POST, OPTIONS"
  response.headers["Access-Control-Allow-Origin"] = "*"
  response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "Content-Type"
  200
end

# Din Stripe Secret Key (test)
Stripe.api_key = ENV['STRIPE_SECRET_KEY']


set :public_folder, "public"

post "/create-checkout-session" do
  content_type :json
headers "Access-Control-Allow-Origin" => "*"

  session = Stripe::Checkout::Session.create(
    payment_method_types: ["card"],
    line_items: [{
      price_data: {
        currency: "usd",
        product_data: {
          name: "Demo Product"
        },
        unit_amount: 2000
      },
      quantity: 1
    }],
    mode: "payment",
    success_url: "https://stripe-checkout2-1.onrender.com/success",
    cancel_url: "https://stripe-checkout2-1.onrender.com/cancel"
  )

  { id: session.id }.to_json
end

get "/" do
  redirect "/index.html"
end

get '/success' do
  send_file File.join(settings.public_folder, 'success.html')
end

get '/cancel' do
  send_file File.join(settings.public_folder, 'cancel.html')
end

