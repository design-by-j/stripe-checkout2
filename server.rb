require "sinatra"
require "stripe"
require "sinatra/cross_origin"
require 'dotenv/load'
require "json"
require 'mail'

options = {
  address: "smtp.mail.me.com",
  port: 587,
  user_name: ENV['EMAIL'],       # ex: johannabsvensson@icloud.com
  password: ENV['EMAIL_PASSWORD'], # ditt appspecifika lösenord
  authentication: 'plain',
  enable_starttls_auto: true
}

Mail.defaults do
  delivery_method :smtp, options
end

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

# Lägg detta högst upp, efter require och konfiguration
PRODUCTS_CATALOG = {
  "pearls" => { name: "Pearls", price: 69900, sold: false },
  "green_drops" => { name: "Green Drops", price: 69900, sold: false },
  "crystal_clear" => { name: "Crystal Clear", price: 69900, sold: false },
  "blue_emerald" => { name: "Blue Emerald", price: 79900, sold: false },
  "moonlight" => { name: "Moonlight", price: 79900, sold: false },
  "gold_leaf" => { name: "Gold Leaf", price: 69900, sold: false },
  "emerald_green_angel" => { name: "Emerald Green Angel", price: 79900, sold: false },
  "golden_elegance" => { name: "Golden Elegance", price: 79900, sold: false },
  "peace_heart" => { name: "Peace Heart", price: 69900, sold: false },
  "crystal_luxury" => { name: "Crystal Luxury", price: 79900, sold: false },
  "true_starlight" => { name: "True Starlight", price: 69900, sold: false },
  "glass_drops" => { name: "Glass Drops", price: 79900, sold: false }
}

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

  # Om frontend skickar visningsnamn (t ex "Pearls"), mappa dem till id:
  # Normaliserar både id och namn till lowercase för matchning.
  name_to_id = {}
  PRODUCTS_CATALOG.each { |id, info| name_to_id[info[:name].downcase] = id }

  # Normalisera indata: om element är display-namn, konvertera till id
  normalized_ids = product_ids.map do |p|
  next nil if p.nil?
  key = p.to_s.strip.downcase
  if PRODUCTS_CATALOG.key?(key) && !PRODUCTS_CATALOG[key][:sold]
    key
  elsif name_to_id.key?(key) && !PRODUCTS_CATALOG[name_to_id[key]][:sold]
    name_to_id[key]
  else
    nil
  end
end.compact

halt 400, { error: "No valid products available (sold out?)" }.to_json if normalized_ids.empty?


  # Räkna kvantiteter av samma produkt
  counts = Hash.new(0)
  normalized_ids.each { |id| counts[id] += 1 }

  # Bygg line_items för Stripe
  line_items = counts.map do |id, qty|
    prod = PRODUCTS_CATALOG[id]
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
      cancel_url: "https://stripe-checkout2-1.onrender.com/cancel",
      metadata: { products: normalized_ids.join(",") },
      shipping_address_collection: {
    allowed_countries: ["SE"]  # Du kan lägga till fler länder, t.ex. ["SE", "NO", "DK"]
  }
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

post "/webhook" do
  begin
    payload = request.body.read
    sig_header = request.env['HTTP_STRIPE_SIGNATURE']
    endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

    event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)

    case event.type
    when 'checkout.session.completed'
      session = event.data.object
      products_bought = session.metadata.products&.split(",") || []
      products_bought.each do |product_id|
        PRODUCTS_CATALOG[product_id][:sold] = true if PRODUCTS_CATALOG[product_id]
      end

      # Hämta adressen
  shipping_info = session.customer_details&.address
  customer_name  = session.customer_details&.name
  customer_email = session.customer_details&.email

  puts "Kundens namn: #{customer_name}"
  puts "Kundens email: #{customer_email}"
  puts "Kundens adress: #{shipping_info}"

  begin
        Mail.deliver do
          from     ENV['EMAIL']
          to       ENV['EMAIL']   # skickas till dig själv
          subject  "Ny order från webbshop"
          body     "Ny order:\n\n" \
                   "Kund: #{customer_name}\n" \
                   "Email: #{customer_email}\n" \
                   "Adress: #{shipping_info.to_h}\n" \
                   "Produkter: #{products_bought.join(', ')}"
        end
      rescue => e
        puts "Fel vid skickande av mejl: #{e.message}"
      end
    end

    status 200
  rescue => e
    puts "Webhook error: #{e.message}"
    puts e.backtrace
    halt 500, "Webhook Error"
  end
end


