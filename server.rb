
require 'stripe'
require 'sinatra'

Stripe.api_key = ENV['STRIPE_SECRET_KEY']

set :port, ENV.fetch('PORT', 4242)   # Render kräver PORT
set :bind, '0.0.0.0'                 # Viktigt för Render
set :static, true
set :public_folder, File.dirname(__FILE__) + '/public'


YOUR_DOMAIN = 'http://localhost:4242'

get "/" do
  send_file File.join(settings.public_folder, 'index.html')
end


post '/create-checkout-session' do
  content_type 'application/json'

  session = Stripe::Checkout::Session.create(
    mode: 'payment',
    success_url: 'https://stripe-checkout-j8yl.onrender.com/return.html',
    cancel_url: 'https://stripe-checkout-j8yl.onrender.com/index.html',
    line_items: [{
      price_data: {
        currency: 'usd',
        product_data: {
          name: 'T-shirt'
        },
        unit_amount: 2000, # $20.00
      },
      quantity: 1
    }]
  )

  { url: session.url }.to_json
end

get '/success' do
  "<h1>✅ Payment successful!</h1>"
end

get '/cancel' do
  "<h1>❌ Payment canceled.</h1>"
end


post '/create-checkout-session' do
  content_type 'application/json'

  session = Stripe::Checkout::Session.create({
    ui_mode: 'embedded',
    line_items: [{
      # Provide the exact Price ID (e.g. price_1234) of the product you want to sell
      price: 'price_1SRsrNLStOKJ123VhpA4hA0W',
      quantity: 1,
    }],
    mode: 'payment',
    return_url: YOUR_DOMAIN + '/return.html?session_id={CHECKOUT_SESSION_ID}',
    automatic_tax: {enabled: true},
  })

  {clientSecret: session.client_secret}.to_json
end

get '/session-status' do
  session = Stripe::Checkout::Session.retrieve(params[:session_id])

  {status: session.status, customer_email:  session.customer_details.email}.to_json
end
