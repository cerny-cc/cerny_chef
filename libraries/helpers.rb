#
# Cookbook:: cerny_chef
# Library:: helpers
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

class Cerny
  class EtcdAPI < Chef::HTTP
    def initialize(servers, fallback)
      api_host = ''
      servers.each do |server|
        begin
          Chef::HTTP.new("http://#{server}:2379").get('/version')
          api_host = server
          break
        rescue
          api_host = fallback
          next
        end
      end
      super("http://#{api_host}:2379")
    end

    def http_retry_count
      1
    end

    def get(key)
      Base64.decode64(JSON.parse(request(:GET, "/v2/keys/#{key}", {}))['node']['value'])
    end

    def put(key, value)
      request(:PUT, "/v2/keys/#{key}", {}, "value=#{Base64.encode64(value)}")
    end

    def check_backend_secrets

    end

    def check_frontend_config

    end

    def check_frontend_secrets

    end
  end
end

def load_backend_secrets
  ::File.read('/etc/chef-backend/chef-backend-secrets.json')
end

def check_backend_secrets(api)
  api.get('_chef_backend/_secrets').eql?(load_backend_secrets)
rescue
  false
end

def load_frontend_config
  cmd = Mixlib::ShellOut.new("/usr/bin/chef-backend-ctl gen-server-config #{node['chef']['api_fqdn']}")
  cmd.run_command.stdout
end

def check_frontend_config(api)
  api.get('_chef_frontend/_config').eql?(load_frontend_config)
rescue
  false
end

def check_frontend_secrets(api)
  %w(private-chef-secrets.json webui_priv.pem webui_pub.pem pivotal.pem).each do |fn|
    unless api.get("_chef_frontend/_#{fn}").eql?(::File.read("/etc/opscode/#{fn}"))
      false
    end
  end
  false unless api.get('_chef_frontend/_migration-level').eql?(::File.read('/var/opt/opscode/upgrades/migration-level'))
  false unless api.get('_chef_frontend/_delivery.pem').eql?(::File.read('/etc/opscode/users/delivery.pem'))
  false unless api.get('_chef_frontend/_cerny-validation.pem').eql?(::File.read('/etc/opscode/orgs/cerny-validation.pem'))
  true
rescue
  false
end
