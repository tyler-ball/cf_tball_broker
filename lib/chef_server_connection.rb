require "chef-api"
require "base64"

ChefAPI.configure do |config|
  # The endpoint for the Chef Server. This can be an Open Source Chef Server,
  # Hosted Chef Server, or Enterprise Chef Server.
  config.endpoint = ENV.fetch("CHEF_API_ENDPOINT")

  # ChefAPI will try to determine if you are running on an Enterprise Chef
  # Server or Open Source Chef depending on the URL you provide for the
  # +endpoint+ attribute. However, it may be incorrect. If is seems like the
  # generated schema does not match the response from the server, it is
  # possible this value was calculated incorrectly. Thus, you should set it
  # manually. Possible values are +:enterprise+ and +:open_source+.
  config.flavor = :enterprise

  # The client and key must also be specified (unless you are running Chef Zero
  # in no-authentication mode). The +key+ attribute may be the raw private key,
  # the path to the private key on disk, or an +OpenSSLL::PKey+ object.
  config.client = ENV.fetch("CHEF_API_CLIENT")
  config.key    = Base64.decode64(ENV.fetch("CHEF_API_KEY"))

  # If you are running your own Chef Server with a custom SSL certificate, you
  # will need to specify the path to a pem file with your custom certificates
  # and ChefAPI will wire everything up correctly. (NOTE: it must be a valid
  # PEM file).
  # config.ssl_pem_file = '/Users/tball/Downloads/tball-test-pcf-qfroezz0nf3quu6n/.chef/ca_certs/opsworks-cm-ca-2016-root.pem'

  # If you would like to be vulnerable to MITM attacks, you can also turn off
  # SSL verification. Despite what Internet blog posts may suggest, you should
  # exhaust other methods before disabling SSL verification. ChefAPI will emit
  # a warning message for every request issued with SSL verification disabled.
  config.ssl_verify = false

  # If you are behind a proxy, Chef API can run requests through the proxy as
  # well. Just set the following configuration parameters as needed.
  # config.proxy_username = 'user'
  # config.proxy_password = 'password'
  # config.proxy_address  = 'my.proxy.server' # or 10.0.0.50
  # config.proxy_port     = '8080'
end
