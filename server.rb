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
  headers "Access-Control-Allow-Origin" => "*"  # CORS

  payload = {}
  begin
    payload = JSON.parse(request.body.read || "{}")
  rescue JSON::ParserError
    halt 400, { error: "Invalid JSON" }.to_json
  end

  # Accept single product_id or products array
  product_ids = []
  if payload["product_id"]
    product_ids << payload["product_id"]
  elsif payload["products"] && payload["products"].is_a?(Array)
    product_ids = payload["products"]
  else
    halt 400, { error: "No product_id or products provided" }.to_json
  end

  # Produktkatalog (nycklar = id som servern använder), priser i öre
  products_catalog = {
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

  # Om frontend skickar visningsnamn (t ex "Pearls"), mappa dem till id:
  # Normaliserar både id och namn till lowercase för matchning.
  name_to_id = {}
  products_catalog.each { |id, info| name_to_id[info[:name].downcase] = id }

  # Normalisera indata: om element är display-namn, konvertera till id
  normalized_ids = product_ids.map do |p|
    next nil if p.nil?
    s = p.to_s.strip
    key = s.downcase
    if products_catalog.key?(key)             # redan ett id som "pearls"
      key
    elsif name_to_id.key?(key)               # ett display-namn som "pearls"
      name_to_id[key]
    else
      nil
    end
  end.compact

  halt 400, { error: "No valid products found" }.to_json if normalized_ids.empty?

  # Räkna kvantiteter av samma produkt
  counts = Hash.new(0)
  normalized_ids.each { |id| counts[id] += 1 }

  # Bygg line_items för Stripe
  line_items = counts.map do |id, qty|
    prod = products_catalog[id]
    {
      price_data: {
        currency: "sek",
        product_data: { name: prod[:name] },
        unit_amount: prod[:price]
      },
      quantity: qty
    }
  end

  begin
    session = Stripe::Checkout::Session.create(
      payment_method_types: ["card"],
      line_items: line_items,
      mode: "payment",
      success_url: "https://stripe-checkout2-1.onrender.com/success",
      cancel_url: "https://stripe-checkout2-1.onrender.com/cancel"
    )
  rescue Stripe::StripeError => e
    halt 500, { error: e.message }.to_json
  end

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

