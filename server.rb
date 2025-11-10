require 'stripe'
require 'sinatra'

# This is your test secret API key.
Stripe.api_key = ENV['STRIPE_SECRET_KEY']


set :static, true
set :port, 4242

YOUR_DOMAIN = 'http://localhost:4242'

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
