require 'logger'
require "sinatra"
require "stripe"
require "sinatra/cross_origin"
require 'dotenv/load'
require "json"
require 'sendgrid-ruby'
include SendGrid

def send_order_email(session)
  begin
    # Skapa från- och till-adresser
    from = Email.new(email: ENV['SENDGRID_FROM'])
    to   = Email.new(email: ENV['SENDGRID_TO'])

    subject = "Ny order från webbshop"

    # Bygg textinnehåll säkert
    customer_name  = session.customer_details&.name || "Okänt namn"
    customer_email = session.customer_details&.email || "Okänt email"
    address = session.customer_details&.address
    address_text = if address
      [
        address.line1,
        address.line2,
        address.postal_code,
        address.city,
        address.country
      ].compact.join(", ")
    else
      "Ingen adress angiven"
    end

    products = session.metadata&.products || "Okänt"

    content_text = <<~TEXT
      Ny order:

      Namn: #{customer_name}
      E-post: #{customer_email}
      Adress: #{address_text}
      Produkter: #{products}
      Checkout session id: #{session.id}
    TEXT

    # Skapa mail-objekt enligt SendGrid
    content = SendGrid::Content.new(type: 'text/plain', value: content_text)
    mail = SendGrid::Mail.new(from, subject, to, content)

    # Skicka mailet
    sg = SendGrid::API.new(api_key: ENV['SENDGRID_API_KEY'])
    response = sg.client.mail._('send').post(request_body: mail.to_json)

    puts "E-post skickad! Status: #{response.status_code}"
    puts "SendGrid response body: #{response.body}" if response.body && !response.body.empty?

  rescue => e
    puts "Fel vid skickande av mejl: #{e.message}"
    puts e.backtrace
  end
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
  "pearls" => { name: "Pearls", price_id: "price_1SRs6qLWqK4VYJz2GVcUewoE", product_id: "prod_TOfRDTXU6NcdSI" },
  "green_drops" => { name: "Green Drops", price_id: "price_1ST3ThLWqK4VYJz2nIk2JkMU", product_id: "prod_TPtGiEqRoeZAM3" },
  "crystal_clear" => { name: "Crystal Clear", price_id: "price_1ST3WsLWqK4VYJz2ftL25jE2", product_id: "prod_TPtJep1gAkgBr6" },
  "blue_emerald" => { name: "Blue Emerald", price_id: "price_1ST3bRLWqK4VYJz27H7SmTc5", product_id: "prod_TPtOFRxDx2scjs" },
  "moonlight" => { name: "Moonlight", price_id: "price_1ST3c5LWqK4VYJz2f2ulNP6v", product_id: "prod_TPtOXe7lMK7gbm" },
  "gold_leaf" => { name: "Gold Leaf", price_id: "price_1ST3d9LWqK4VYJz2gaYCIMhC", product_id: "prod_TPtPAiVGfXlstg" },
  "emerald_green_angel" => { name: "Emerald Green Angel", price_id: "price_1ST3e7LWqK4VYJz2p6F4oBHo", product_id: "prod_TPtQmd2lI9kUUF" },
  "golden_elegance" => { name: "Golden Elegance", price_id: "price_1ST3g0LWqK4VYJz2MCOxndRz", product_id: "prod_TPtSOvPGWUd1Py" },
  "peace_heart" => { name: "Peace Heart", price_id: "price_1ST3gdLWqK4VYJz2RbPTmL1g", product_id: "prod_TPtTMyGVnpAKwt" },
  "crystal_luxury" => { name: "Crystal Luxury", price_id: "price_1ST3i7LWqK4VYJz2YOqsHvqO", product_id: "prod_TPtV0RU3SWqlDk" },
  "true_starlight" => { name: "True Starlight", price_id: "price_1ST3j9LWqK4VYJz2k2ujkg2E", product_id: "prod_TPtWlUXyLEPUsE" },
  "glass_drops" => { name: "Glass Drops", price_id: "price_1ST3jxLWqK4VYJz2yWlBuqBe", product_id: "prod_TPtXtuhn9uS7Wj" } 
}



post "/create-checkout-session" do
  content_type :json
  request.body.rewind if request.body.respond_to?(:rewind)
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
  product = PRODUCTS_CATALOG[id]
  halt 400, { error: "Ogiltigt produkt-ID" }.to_json unless product

  {
    price: product[:price_id],
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

get "/health" do
  content_type :json
  { status: "ok", timestamp: Time.now.to_i }.to_json
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
        catalog_entry = PRODUCTS_CATALOG[product_id]
        next unless catalog_entry

        # Hämta Stripe product_id
        stripe_product_id = catalog_entry[:product_id]

        # Hämta aktuell produkt från Stripe
        product = Stripe::Product.retrieve(stripe_product_id)

        # Minska stock
        current_stock = product.metadata['stock'].to_i
        new_stock = [current_stock - 1, 0].max

        Stripe::Product.update(
          stripe_product_id,
          metadata: { stock: new_stock }
        )

        # Markera som sold i lokalt katalog om stock = 0
        catalog_entry[:sold] = true if new_stock == 0
      end


      # Hämta adressen
  shipping_info  = session.customer_details&.address
  customer_name  = session.customer_details&.name
  customer_email = session.customer_details&.email

  puts "Kundens namn: #{customer_name}"
  puts "Kundens email: #{customer_email}"
  puts "Kundens adress: #{shipping_info}"

  send_order_email(session)
    end

    status 200
  rescue => e
    puts "Webhook error: #{e.message}"
    puts e.backtrace
    halt 500, "Webhook Error"
  end
end

get "/product-stock" do
  content_type :json
  product_id = params["product_id"]
  catalog_entry = PRODUCTS_CATALOG[product_id]
  halt 404, { error: "Produkt ej hittad" }.to_json unless catalog_entry

  stripe_product_id = catalog_entry[:product_id]
  product = Stripe::Product.retrieve(stripe_product_id)

  { stock: product.metadata["stock"].to_i }.to_json
end



