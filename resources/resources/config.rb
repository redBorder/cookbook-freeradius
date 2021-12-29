#Cookbook Name :: rbnmsp
#
# Resource:: config
#

actions :add, :remove , :register, :deregister
default_action :add

attribute :config_dir, :kind_of => String, :default => "/etc/redborder-nmsp"
attribute :kafka_topic, :kind_of => String, :default => "rb_nmsp"
attribute :name, :kind_of => String, :default => "localhost"
attribute :ip, :kind_of => String, :default => "127.0.0.1"
attribute :flow_nodes, :kind_of => Array, :default => []
attribute :proxy_nodes, :kind_of => Hash, :default => {}
attribute :memory, :kind_of => Fixnum, :default => 0
attribute :hosts, :kind_of => Object

