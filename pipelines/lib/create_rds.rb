module Build
  module Acceptance
    class CreateRds < EnvironmentConfiguration
      require 'json'
      include BlogRefactorGem::Utils::Cfn
      def initialize(store:)
        super(store: store)

        params = store.get(attrib_name: 'params')
        params[:rds_password] = ENV['rds_password'] || 'example123'
        params[:rds_username] = ENV['rds_username'] || 'example123'
        params[:rds_stack_name] = "rds-#{params[:app_name]}"

        stack_info = BlogRefactorGem::Utils::Cfn.get_stack(region: params[:aws_region], name: params[:rds_stack_name])
        stack_info = create_rds(params: params) if stack_info.nil?

        params[:rds_endpoint] = stack_info.outputs.select { |output| output[:output_key] == "DBEndpoint" }[0][:output_value]
        params[:asg_stack_name] = "#{params[:app_name]}-#{Time.now.to_i}"
        params[:chef_json_key] = "#{params[:asg_stack_name]}.json"
        chef_json = {
          run_list: [params[:app_name]],
          greeter: {
            db_url: params[:rds_endpoint],
            db_name: params[:app_name],
            username: params[:rds_username],
            password: params[:rds_password],
            docroot: "/var/www/#{params[:app_name]}"
          }
        }
        Aws::S3::Client.new(region: 'us-east-1').put_object({
          body: chef_json.to_json,
          bucket: "stelligent-blog",
          key: "chefjson/jsons/#{params[:chef_json_key]}"
        })
      end

      def create_rds(params:)
        put_stack(
          region: params[:aws_region],
          name: params[:rds_stack_name],
          template_url: 'https://s3.amazonaws.com/stelligent-blog/chefjson/templates/mysql-rds.template.json',
          parameters: {
            VpcId: params[:aws_vpc],
            AppName: params[:app_name],
            DBSubnetGroupID: 'matt-test',
            DBInstanceIdentifier: params[:rds_stack_name],
            DBName: params[:app_name],
            DBUsername: params[:rds_username],
            DBPassword: params[:rds_password],
            DBParameterGroupName: 'default.mysql5.6'
          },
          tags: [
            { key: 'application', value: params[:app_name] },
            { key: 'branch', value: params[:repository_branch] }
          ]
        )
      end
    end
  end
end
