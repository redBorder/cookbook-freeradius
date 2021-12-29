#
# Cookbook Name:: rbfreeradius
# Recipe:: default
#
# redborder
#
#

rbfreeradius_config "config" do
  name node["hostname"]
  action :add
end
