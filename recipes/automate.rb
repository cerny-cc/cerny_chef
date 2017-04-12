#
# Cookbook:: cerny_chef
# Recipe:: automate
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

# firewall 'default' do
#   action :install
#   enabled_zone :external
# end
#
# firewall_rule 'ssh' do
#   protocol :tcp
#   port 22
#   notifies :save, 'firewall[default]'
# end
#
# firewall_rule 'delivery-external' do
#   protocol :tcp
#   port [80, 443, 8989]
#   notifies :save, 'firewall[default]'
# end

api = etcd_api

begin
  delivery_pem = JSON.parse(Base64.decode64(api.get('/v2/keys/_chef_frontend/_delivery.pem')))['node']['value']
  validation_pem = JSON.parse(Base64.decode64(api.get('/v2/keys/_chef_frontend/_validation.pem')))['node']['value']
rescue
  raise('Unable to get configuration from etcd!')
end

builder_pem =
  begin
    JSON.parse(Base64.decode64(api.get("/v2/keys/_chef_automate/_builder_pem")))['node']['value']
  rescue
    Chef::Log.warn('Unable to load builder_pem from etcd.  Assuming first run.')
    OpenSSL::PKey::RSA.new(2048).to_pem
  end

es_urls = []
node['chef']['backends'].each do |be|
  es_urls << "http://#{be}:9200,"
end

chef_automate node['fqdn'] do
  version '0.6.136'
  config <<-EOF
    elasticsearch['urls'] = "#{es_urls.join(',')}"
    nginx['fqdns'] = [ "#{node['chef']['aautomate_fqdn']}", "#{node['fqdn']}" ]
    compliance_profiles['enable'] = true
  EOF
  accept_license true
  enterprise 'cerny-cc'
  license nil
  chef_user 'delivery'
  chef_user_pem delivery_pem
  validation_pem validation_pem
  builder_pem builder_pem
end

ruby_block 'Upload Automate Secrets' do
  block do
    api.put("/v2/keys/_chef_automate/_builder_pem","value=#{Base64.encode64(builder_pem)}")
  end
  # not_if { check_frontend_secrets(api) }
end
