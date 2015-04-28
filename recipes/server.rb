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
node.set_unless['sensu']['api']['password'] = random_string(20)
node.set_unless['sensu']['rabbitmq']['password'] = random_string(20)
node.set_unless['sensu']['host'] = node[:fqdn]

apt_repository 'rabbitmq' do
    uri          'http://www.rabbitmq.com/debian/'
    components   ['testing', 'main']
    key          'http://www.rabbitmq.com/rabbitmq-signing-key-public.asc'
end

packages = %w{ redis-server erlang-nox rabbitmq-server ruby1.9.1-dev build-essential }

packages.each do |pkg|
    package pkg
end

gems = %w{ sensu-plugin hipchat timeout redphone }

gems.each do |gem|
    gem_package gem
end

# Build a list of all clients registered in chef with the sensu-client role
clients = Array.new

search(:node, "role:sensu-client") do |client|
    clients << client
end

nameservers = Array.new

search(:node, "role:NS") do |nameserver|
    nameservers << nameserver
end

# Load data bags containing HTTP(/S) checks
httpcheck = data_bag_item("sensu", "httpcheck")

service "sensu-server" do
    action [ :enable ]
    supports :status => true, :restart => true, :reload => true, :stop => true
end

service "sensu-api" do
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
    command "rabbitmqctl add_user sensu #{node[:sensu][:rabbitmq][:password]}"
    notifies :create, "ruby_block[rabbitmqinit]", :delayed
    not_if { node.attribute?("rabbitmqinit") }
end

execute "rabbitmq-permission" do
    command "rabbitmqctl set_permissions -p /sensu sensu \".*\" \".*\" \".*\""
    notifies :create, "ruby_block[rabbitmqinit]", :delayed
    not_if { node.attribute?("rabbitmqinit") }
end

execute "rabbitmq-delete" do
    command "rabbitmqctl delete_user guest"
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

# Install client keys on sensu-server
directory "/etc/sensu/ssl" do
    recursive true
end

%w{ cert key }.each do |item|
    file "/etc/sensu/ssl/#{item}.pem" do
        content sensu["client"][item]
        mode "0644"
        notifies :restart, resources(:service => "sensu-server"), :delayed
        notifies :restart, resources(:service => "sensu-api"), :delayed
    end
end

template "/etc/sensu/conf.d/rabbitmq.json" do
    source "rabbitmq.json.erb"
    mode 0644
    owner   "root"
    group   "root"
    notifies :restart, resources(:service => "sensu-server"), :delayed
    notifies :restart, resources(:service => "sensu-api"), :delayed
end

template "/etc/sensu/conf.d/redis.json" do
    source "redis.json.erb"
    mode 0644
    owner   "root"
    group   "root"
    notifies :restart, resources(:service => "sensu-server"), :delayed
    notifies :restart, resources(:service => "sensu-api"), :delayed
end

template "/etc/sensu/conf.d/api.json" do
    source "api.json.erb"
    mode 0644
    owner   "root"
    group   "root"
    notifies :restart, resources(:service => "sensu-server"), :delayed
    notifies :restart, resources(:service => "sensu-api"), :delayed
end

template "/etc/sensu/conf.d/checks.json" do
    source "checks.json.erb"
    mode 0644
    owner   "root"
    group   "root"
    notifies :restart, resources(:service => "sensu-server"), :delayed
    notifies :restart, resources(:service => "sensu-api"), :delayed
    variables :clients => clients, :httpcheck => httpcheck
end

# PagerDuty-integration
cookbook_file "victorops.rb" do
        path "/etc/sensu/handlers/victorops.rb"
        action :create
        mode 0755
        owner "root"
        group "root"
        notifies :restart, resources(:service => "sensu-server"), :delayed
        notifies :restart, resources(:service => "sensu-api"), :delayed
end

template "/etc/sensu/conf.d/victorops.json" do
        source "victorops.json.erb"
        mode 0644
        owner   "root"
        group   "root"
        notifies :restart, resources(:service => "sensu-server"), :delayed
        notifies :restart, resources(:service => "sensu-api"), :delayed
end

template "/etc/sensu/conf.d/handlers.json" do
        source "handlers.json.erb"
        mode 0644
        owner   "root"
        group   "root"
        notifies :restart, resources(:service => "sensu-server"), :delayed
        notifies :restart, resources(:service => "sensu-api"), :delayed
end

# # Create folders for extensions and mutators.
# %w{ handlers mutators }.each do |item|
# 	directory "/etc/sensu/extensions/#{item}" do
# 		recursive true
# 	end
# end

# cookbook_file "relay.rb" do
#         path "/etc/sensu/extensions/handlers/relay.rb"
#         action :create
#         mode 0644
#         owner "root"
#         group "root"
#         notifies :restart, resources(:service => "sensu-server"), :delayed
#         notifies :restart, resources(:service => "sensu-api"), :delayed
# end

# cookbook_file "metrics.rb" do
#         path "/etc/sensu/extensions/mutators/metrics.rb"
#         action :create
#         mode 0644
#         owner "root"
#         group "root"
#         notifies :restart, resources(:service => "sensu-server"), :delayed
#         notifies :restart, resources(:service => "sensu-api"), :delayed
# end

# template "/etc/sensu/conf.d/relay.json" do
#         source "relay.json.erb"
#         mode 0644
#         owner   "root"
#         group   "root"
#         notifies :restart, resources(:service => "sensu-server"), :delayed
#         notifies :restart, resources(:service => "sensu-api"), :delayed
# end

# template "/etc/sensu/conf.d/metrics.json" do
#         source "metrics.json.erb"
#         mode 0644
#         owner "root"
#         group "root"
#         notifies :restart, resources(:service => "sensu-server"), :delayed
#         notifies :restart, resources(:service => "sensu-api"), :delayed
# end
