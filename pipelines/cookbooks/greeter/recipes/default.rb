include_recipe "apt"
include_recipe "php"
include_recipe "php::module_mysql"
include_recipe "apache2::mod_php5"
include_recipe "apache2"

apache_site "default" do
  enable true
end

apache_module "mpm_event" do
  enable false
end

apache_module "mpm_prefork" do
  enable true
end

web_app 'greeter' do
  template 'site.conf.erb'
  docroot node[:greeter][:docroot]
  server_name node[:greeter][:server_name]
end

cookbook_file "/tmp/db.seed" do
  source 'db.seed'
  owner 'root'
  group 'root'
  mode '755'
end

execute "seed database" do
  command "mysql -u #{node[:greeter][:username]} -p#{node[:greeter][:password]} -h #{node[:greeter][:db_url]} #{node[:greeter][:db_name]} < /tmp/db.seed"
end

execute "mkdir #{node[:greeter][:docroot]}" do
  command "mkdir #{node[:greeter][:docroot]}"
end

template "#{node[:greeter][:docroot]}/index.php" do
  source 'index.php.erb'
  owner 'www-data'
  group 'www-data'
  mode '755'
end

script 'install cfn-init' do
  interpreter "bash"
  code <<-EOH
    apt-get -y install python-setuptools
    wget -P /root https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz
    mkdir -p /root/aws-cfn-bootstrap-latest
    tar xvfz /root/aws-cfn-bootstrap-latest.tar.gz --strip-components=1 -C /root/aws-cfn-bootstrap-latest
    easy_install /root/aws-cfn-bootstrap-latest/
  EOH
end
