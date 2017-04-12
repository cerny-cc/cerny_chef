#
# Cookbook:: cerny_chef
# Recipe:: frontend
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

hostsfile_entry '127.0.0.1' do
  hostname 'chef.cerny.cc'
  aliases ['chef']
  action :append
end

execute 'firewall_rule[ssh]' do
  command 'firewall-cmd --zone=public --add-service=ssh'
end

execute 'firewall_rule[frontend]' do
  command <<-EOH
    firewall-cmd --zone=public --add-port=80/tcp
    firewall-cmd --zone=public --add-port=443/tcp
  EOH
end

api = Cerny::EtcdAPI.new(node['chef']['backends'], node['fqdn'])

frontend_config =
  begin
    api.get('_chef_frontend/_config')
  rescue
    raise('Unable to get configuration from etcd!')
  end

frontend_secrets = Hash.new
begin
  %w(private-chef-secrets.json webui_priv.pem webui_pub.pem pivotal.pem).each do |fn|
    frontend_secrets["/etc/opscode/#{fn}"] = api.get("_chef_frontend/_#{fn}")
  end
  frontend_secrets['/var/opt/opscode/upgrades/migration-level'] = api.get('_chef_frontend/_migration-level')
  frontend_secrets['/etc/opscode/users/delivery.pem'] = api.get('_chef_frontend/_delivery.pem')
  frontend_secrets['/etc/opscode/orgs/cerny-validation.pem'] = api.get('_chef_frontend/_cerny-validation.pem')
rescue
  Chef::Log.warn('Unable to load secrets from etcd.  Assuming first node.')
  nil
end

directory '/etc/opscode'
directory '/etc/opscode/users'
directory '/etc/opscode/orgs'
directory '/var/opt/opscode/upgrades/' do
  recursive true
end
frontend_secrets.each do |fn, cts|
  file fn do
    content cts
  end
end
file '/var/opt/opscode/bootstrapped'

chef_server node['fqdn'] do
  version '12.13.0'
  config frontend_config
  accept_license true
  addons Hash.new
end

chef_user 'delivery' do
  first_name 'Automate'
  last_name 'Administrator'
  email 'delivery@cerny.cc'
end

chef_org 'cerny' do
  admins ['delivery']
end

ruby_block 'Upload Frontend Secrets' do
  block do
    %w(private-chef-secrets.json webui_priv.pem webui_pub.pem pivotal.pem).each do |fn|
      api.put("_chef_frontend/_#{fn}", ::File.read("/etc/opscode/#{fn}"))
    end
    api.put('_chef_frontend/_migration-level', ::File.read('/var/opt/opscode/upgrades/migration-level'))
    api.put('_chef_frontend/_delivery.pem', ::File.read('/etc/opscode/users/delivery.pem'))
    api.put('_chef_frontend/_cerny-validation.pem', ::File.read('/etc/opscode/users/cerny-validation.pem'))
  end
  not_if { check_frontend_secrets(api) }
end
