#
# Cookbook:: cerny_chef
# Recipe:: backend
#
# Copyright:: 2017, Nathan Cerny
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

require 'base64'

include_recipe 'ntp'

execute 'firewall_rule[ssh]' do
  command 'firewall-cmd --zone=public --add-service=ssh'
end

execute 'firewall_rule[backend]' do
  command <<-EOH
    firewall-cmd --zone=public --add-port=2379/tcp
    firewall-cmd --zone=public --add-port=2380/tcp
    firewall-cmd --zone=public --add-port=5432/tcp
    firewall-cmd --zone=public --add-port=7331/tcp
    firewall-cmd --zone=public --add-port=9200/tcp
    firewall-cmd --zone=public --add-port=9300/tcp
  EOH
end

api = Cerny::EtcdAPI.new(node['chef']['backends'], node['fqdn'])

backend_secrets =
  begin
    api.get('_chef_backend/_secrets')
  rescue
    Chef::Log.warn('Cannot Connect to etcd.  Assuming first node.')
    ''
  end

directory '/etc/chef-backend'

chef_backend node['fqdn'] do
  version '1.3.2'
  accept_license true
  peers node['chef']['backends']
  chef_backend_secrets backend_secrets
end

ruby_block 'Upload Backend Secrets' do
  block do
    api.put('_chef_backend/_secrets', load_backend_secrets)
  end
  not_if { check_backend_secrets(api) }
end

ruby_block 'Upload Frontend Configuration' do
  block do
    api.put('_chef_frontend/_config', load_frontend_config)
  end
  not_if { check_frontend_secrets(api) }
end
