require "sinatra"
require "stripe"
require 'dotenv/load'
require "json"

# Din Stripe Secret Key (test)
Stripe.api_key = ENV['STRIPE_SECRET_KEY']


set :public_folder, "public"

post "/create-checkout-session" do
  content_type :json

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
    success_url: "http://localhost:4242/success.html",
    cancel_url: "http://localhost:4242/cancel.html"
  )

  { id: session.id }.to_json
end

get "/" do
  redirect "/index.html"
end

