# Cookbook:: freeradius
# Recipe:: default
# Copyright:: 2024, redborder
# License:: Affero General Public License, Version 3

freeradius_config 'config' do
  name node['hostname']
  action :config_common
end
