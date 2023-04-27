#
# Cookbook Name:: freeradius
# Recipe:: default
#
# redborder
#
#

freeradius_config "config" do
  name node["hostname"]
  action :config_common
end
