
require 'stripe'
require 'sinatra'

Stripe.api_key = ENV['STRIPE_SECRET_KEY']

set :port, ENV.fetch('PORT', 4242)   # Render kräver PORT
set :bind, '0.0.0.0'                 # Viktigt för Render
set :static, true
set :public_folder, File.dirname(__FILE__) + '/public'


YOUR_DOMAIN = 'http://localhost:4242'

get "/" do
  "Hello from Stripe Checkout app — deployment successful! 🚀"
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
