#
# Cookbook Name:: sensu
# Recipe:: server
#
# Copyright (C) YEAR YOUR_NAME <YOUR_EMAIL>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Install/configure something here

# Load keys for SSL
sensu = data_bag_item("sensu", "ssl")

# Generate passwords
node.set_unless['api']['password'] = random_string(20)
node.set_unless['rabbitmq']['password'] = random_string(20)
node.default['sensu']['host'] = node[:hostname]

apt_repository 'rabbitmq' do
  uri          'http://www.rabbitmq.com/debian/'
  components   ['testing', 'main']
  key          'http://www.rabbitmq.com/rabbitmq-signing-key-public.asc'
end

packages = %w{redis-server erlang-nox rabbitmq-server}

packages.each do |pkg|
	package pkg
end

service "sensu-server" do
	action [ :enable ]
	supports :status => true, :restart => true, :reload => true, :stop => true
end		

service "sensu-api" do
        action [ :enable ]
        supports :status => true, :restart => true, :reload => true, :stop => true
end

service "sensu-client" do
        action [ :enable ]
        supports :status => true, :restart => true, :reload => true, :stop => true
end

service "rabbitmq-server" do
        action [ :enable ]
        supports :status => true, :restart => true, :reload => true, :stop => true
end

service "redis-server" do
        action [ :enable ]
        supports :status => true, :restart => true, :reload => true, :stop => true
end

directory "/etc/rabbitmq/ssl" do
	recursive true
end

%w{ cert key cacert }.each do |item|
        file "/etc/rabbitmq/ssl/#{item}.pem" do
                content sensu["server"][item]
        end
end

template "/etc/rabbitmq/rabbitmq.config" do
	source "rabbitmq.config.erb"
	mode 0644
	owner	"root"
	group	"root"
	notifies :restart, resources(:service => "rabbitmq-server"), :delayed
end

execute "rabbitmq-vhost" do
	command "rabbitmqctl add_vhost /sensu"
	notifies :create, "ruby_block[rabbitmqinit]", :delayed
	not_if { node.attribute?("rabbitmqinit") }
end

execute "rabbitmq-user" do
	command "rabbitmqctl add_user sensu #{node[:rabbitmq][:password]}" 
	notifies :create, "ruby_block[rabbitmqinit]", :delayed
	not_if { node.attribute?("rabbitmqinit") }
end

execute "rabbitmq-permission" do
	command "rabbitmqctl set_permissions -p /sensu sensu \".*\" \".*\" \".*\""
	notifies :create, "ruby_block[rabbitmqinit]", :delayed
	not_if { node.attribute?("rabbitmqinit") }
end

ruby_block "rabbitmqinit" do
	block do
		node.set['rabbitmqinit'] = true
		node.save
	end
	action :nothing
end

directory "/etc/sensu/ssl" do
	recursive true
end

%w{ cert key }.each do |item|
        file "/etc/sensu/ssl/#{item}.pem" do
                content sensu["client"][item]
        end
end

sensu_server = search(:node, 'role:sensu-server')

template "/etc/sensu/conf.d/rabbitmq.json" do
        source "rabbitmq.json.erb"
        mode 0644
        owner   "root"
        group   "root"
	variables :sensu_server => sensu_server
        notifies :restart, resources(:service => "sensu-server"), :delayed
end

template "/etc/sensu/conf.d/redis.json" do
        source "redis.json.erb"
        mode 0644
        owner   "root"
        group   "root"
        notifies :restart, resources(:service => "sensu-server"), :delayed
end

template "/etc/sensu/conf.d/api.json" do
        source "api.json.erb"
        mode 0644
        owner   "root"
        group   "root"
        notifies :restart, resources(:service => "sensu-api"), :delayed
end


