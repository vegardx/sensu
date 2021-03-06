#
# Cookbook Name:: sensu
# Recipe:: client
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

%w{ ruby1.9.1-dev build-essential nagios-plugins }.each do |pkg|
        package pkg
end

gem_package "sensu-plugin" do
	action :install
end

service "sensu-client" do
        action [ :enable ]
        supports :status => true, :restart => true, :reload => true, :stop => true
end

directory "/etc/sensu/ssl" do
        recursive true
end

%w{ cert key }.each do |item|
    file "/etc/sensu/ssl/#{item}.pem" do
        content sensu["client"][item]
        mode "0644"
        notifies :restart, resources(:service => "sensu-client"), :delayed
    end
end

sensu_server = search(:node, 'role:sensu-server')
node.set[:sensu][:rabbitmq][:password] = sensu_server.first['sensu']["rabbitmq"]["password"]
node.set[:sensu][:rabbitmq][:user] = sensu_server.first['sensu']["rabbitmq"]["user"]
node.set[:sensu][:host] = sensu_server.first["sensu"]["host"]

template "/etc/sensu/conf.d/rabbitmq.json" do
        source "rabbitmq.json.erb"
        mode 0644
        owner   "root"
        group   "root"
        notifies :restart, resources(:service => "sensu-client"), :delayed
end

template "/etc/sensu/conf.d/client.json" do
        source "client.json.erb"
        mode 0644
        owner   "root"
        group   "root"
        notifies :restart, resources(:service => "sensu-client"), :delayed
end

%w{ check-cpu.rb check-disk-fail.rb check-hardware-fail.rb check-mem.sh check-http.rb check-chef.sh check-file-exists.sh check-raid.rb }.each do |item|
        cookbook_file "#{item}" do
                path "/etc/sensu/plugins/#{item}"
                action :create
                mode 0755
                owner "root"
                group "root"
		notifies :restart, resources(:service => "sensu-client"), :delayed
        end
end

# We don't yet implement metrics in Sensu
# %w{ disk-capacity-metrics.rb disk-metrics.rb entropy-metrics.rb interface-metrics.rb load-metrics.rb memory-metrics.rb metrics-curl.rb }.each do |item|
#         cookbook_file "#{item}" do
#                 path "/etc/sensu/plugins/#{item}"
#                 action :create
#                 mode 0755
#                 owner "root"
#                 group "root"
#                 notifies :restart, resources(:service => "sensu-client"), :delayed
#         end
# end
