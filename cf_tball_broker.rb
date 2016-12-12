require 'json'
require_relative 'lib/chef_server_connection'
require_relative 'lib/provisioner'

class CfTballBroker < Sinatra::Base
  set :public_folder => "public", :static => true

  # Catalog
  get "/v2/catalog", :provides => :json do
    {services: get_services}.to_json
  end

  # Create service
  put "/v2/service_instances/:instance_id", :provides => :json do
    pass unless request.accept? 'application/json'

    instance_id = params['instance_id']
    parsed_body = JSON.parse(request.body.read, symbolize_names: true)
    service_id = parsed_body[:service_id]
    plan_id = parsed_body[:plan_id]
    parameters = parsed_body[:parameters]

    if mapping_bag.items.fetch(instance_id)
      status 409
      {}.to_json
    else
      mapping_bag.items.create(id: instance_id, service_id: service_id, plan_id: plan_id, parameters: parameters, bindings: {}, last_operation: "in progress")
      Thread.new { Provisioner.new.converge_machine(instance_id, service_id) }
      status 202
      {dashboard_url: "https://docs.chef.io/#{instance_id}"}.to_json
    end
  end

  # Polling endpoint waiting until instance is created
  get "/v2/service_instances/:instance_id/last_operation", :provides => :json do
    pass unless request.accept? 'application/json'

    instance_id = params['instance_id']
    instance_item = mapping_bag.items.fetch(instance_id)

    status 200
    {state: instance_item.data["last_operation"]}.to_json
  end

  # Bind service
  put "/v2/service_instances/:instance_id/service_bindings/:binding_id", :provides => :json do
    pass unless request.accept? 'application/json'

    instance_id = params['instance_id']
    binding_id = params['binding_id']
    parsed_body = JSON.parse(request.body.read, symbolize_names: true)

    instance_item = mapping_bag.items.fetch(instance_id)
    bindings = instance_item.data["bindings"]
    if bindings[binding_id]
      status 409
      {
        description: "Binding #{binding_id} already exists for instance #{instance_id}"
      }.to_json
    else
      bindings[binding_id] = {bind_resource: parsed_body[:bind_resource], parameters: parsed_body[:parameters]}
      instance_item.save
      # We don't do anything for the binding for this demo
      status 201
      {
        credentials: instance_item.data["credentials"]
      }.to_json
    end
  end

  # unbind service
  delete "/v2/service_instances/:instance_id/service_bindings/:binding_id" do
    instance_id = params['instance_id']
    binding_id = params['binding_id']

    instance_item = mapping_bag.items.fetch(instance_id)
    bindings = instance_item.data["bindings"]

    if bindings[binding_id]
      bindings.delete(binding_id)
      instance_item.save
      status 200
      {}.to_json
    else
      status 410
      {}.to_json
    end
  end

  # delete service
  delete "/v2/service_instances/:instance_id" do
    instance_id = params['instance_id']

    if mapping_bag.items.fetch(instance_id)
      mapping_bag.items.destroy(instance_id)
      status 200
      {}.to_json
    else
      status 410
      {}.to_json
    end
  end

  def get_services
    services = []
    services_bag.items.each do |i|
      services << i.to_hash
    end
    services
  end

  def services_bag
    create_or_fetch_bag('cloudfoundry_services')
  end

  def mapping_bag
    create_or_fetch_bag('cloudfoundry_service_mapping')
  end

  def chef_server
    @chef_server ||= ChefAPI::Connection.new
  end

  private

  def create_or_fetch_bag(name)
    if bag = chef_server.data_bags.fetch(name)
      bag
    else
      chef_server.data_bags.create(name: name)
    end
  end
end
