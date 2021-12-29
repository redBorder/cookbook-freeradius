#
# Cookbook Name:: rbnmsp
# Recipe:: default
#
# redborder
#
#

rbnmsp_config "config" do
  name node["hostname"]
  action :add
end
