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

  # Hämta vilket produkt-ID som skickades från frontend
  request_payload = JSON.parse(request.body.read)
  product_id = request_payload["product_id"]

  # Lista alla produkter och priser i ören (Stripe kräver belopp i lägsta valutaenhet)
  products = {
    "pearls" => { name: "Pearls", price: 69900 },
    "green_drops" => { name: "Green Drops", price: 69900 },
    "crystal_clear" => { name: "Crystal Clear", price: 69900 },
    "blue_emerald" => { name: "Blue Emerald", price: 79900 },
    "moonlight" => { name: "Moonlight", price: 79900 },
    "gold_leaf" => { name: "Gold Leaf", price: 69900 },
    "emerald_green_angel" => { name: "Emerald Green Angel", price: 79900 },
    "golden_elegance" => { name: "Golden Elegance", price: 79900 },
    "peace_heart" => { name: "Peace Heart", price: 69900 },
    "crystal_luxury" => { name: "Crystal Luxury", price: 79900 },
    "true_starlight" => { name: "True Starlight", price: 69900 },
    "glass_drops" => { name: "Glass Drops", price: 79900 }
  }

  # Kolla att produkt-id finns
  product = products[product_id]
  halt 400, { error: "Invalid product_id" }.to_json unless product

  # Skapa Stripe Checkout Session
  session = Stripe::Checkout::Session.create(
    payment_method_types: ["card"],
    line_items: [{
      price_data: {
        currency: "sek",
        product_data: {
          name: product[:name]
        },
        unit_amount: product[:price]
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

