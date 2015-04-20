require 'aws-sdk'
require 'chef-api'

# The following environment variables are required to run:
#
# CHEF_API_ENDPOINT
# CHEF_API_CLIENT
# CHEF_API_KEY
# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY
# AWS_REGION

class NodeCleaner
  include ChefAPI::Resource

  def run
    ec2_client = Aws::EC2::Client.new
    response = ec2_client.describe_instances(filters: [{ name: 'instance-state-name', values: ['pending', 'running'] }])
    instances = Set.new

    response.reservations.each do |reservation|
      reservation.instances.each do |instance|
        instances << instance.private_dns_name
      end
    end

    logger.info "INSTANCES: #{instances.to_a.join(', ')}"

    Node.list.each do |node|
      unless instances.include?(node)
        begin
          logger.info "DELETE NODE: #{node}"
          Node.destroy(node)
        rescue ChefAPI::Error::ChefAPIError => e
          logger.error "Failed to delete node: #{node}"
          logger.error e.message
        end
      end
    end

    Client.list.each do |client|
      if client =~ /ec2/ && !instances.include?(client)
        begin
          logger.info "DELETE CLIENT: #{client}"
          Client.destroy(client)
        rescue ChefAPI::Error::ChefAPIError => e
          logger.error "Failed to delete client: #{client}"
          logger.error e.message
        end
      end
    end
  end

  def logger
    @logger ||= Logger.new(STDOUT)
  end
end

NodeCleaner.new.run
