require 'cheffish'
require 'cheffish/chef_run'
require 'base64'

class Provisioner

  attr_reader :cr
  def initialize
    @cr = Cheffish::ChefRun.new(
      :ssl_verify_mode => :verify_none,
      :log_level => :info,
      :log_location => File.open("/Users/tball/github/cf_tball_broker/provisioning.out", "w")
    )
  end

  def converge_machine(instance_id, service_id)
    cr.compile_recipe do
      require 'chef/provisioning/aws_driver'
      Chef::Config.chef_provisioning = {}
      Chef::Config[:chef_provisioning] = {}

      with_driver 'aws:tester:us-west-2'
      Chef::Config.chef_provisioning = {}
      Chef::Config[:chef_provisioning] = {}

      with_chef_server(ENV.fetch("CHEF_API_ENDPOINT"),
        :client_name => ENV.fetch("CHEF_API_CLIENT"),
        :raw_key => Base64.decode64(ENV.fetch("CHEF_API_KEY")),
        :ssl_verify_mode => :verify_none)

      aws_vpc 'tyler_test_vpc' do
        cidr_block '192.168.0.0/16'
        internet_gateway true
        enable_dns_hostnames true
        main_routes '0.0.0.0/0' => :internet_gateway
      end

      aws_key_pair 'tyler_test_provisioning' do
        allow_overwrite true
      end

      aws_security_group 'tyler_test_sg' do
        vpc 'tyler_test_vpc'
        inbound_rules [
          {:port => -1, :protocol => -1, :sources => ["0.0.0.0/0"] }
        ]
        outbound_rules [
          {:port => -1, :protocol => -1, :destinations => ["0.0.0.0/0"] }
        ]
      end

      aws_subnet 'tyler_test_subnet' do
        vpc 'tyler_test_vpc'
        cidr_block '192.168.0.0/24'
        map_public_ip_on_launch true
        availability_zone lazy { (driver.ec2_client.describe_availability_zones.availability_zones.map {|r| r.zone_name}).first }
      end

      machine "#{instance_id}-#{service_id}" do
        machine_options(
          bootstrap_options: {
            key_name: 'tyler_test_provisioning',
            security_group_ids: 'tyler_test_sg',
            instance_type: 'm3.medium',
            subnet_id: 'tyler_test_subnet',
            image_id: 'ami-73208813'
          },
          convergence_options: {
            ssl_verify_mode: :verify_none,
          }
        )
        attributes({pcf: {instance_id: instance_id}})
        run_list ["recipe[pcf-redis]"]
        action :converge
      end
    end
    cr.converge
  end
end
