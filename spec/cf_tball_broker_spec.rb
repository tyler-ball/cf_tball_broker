require_relative "spec_helper"
require_relative "../cf_tball_broker.rb"

def app
  CfTballBroker
end

describe CfTballBroker do
  it "responds with a welcome message" do
    get '/'

    last_response.body.must_include 'Welcome to the Sinatra Template!'
  end
end
