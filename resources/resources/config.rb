# Cookbook:: freeradius
# Resource:: config

actions :config_common, :config_manager, :remove, :register, :deregister
default_action :config_common

attribute :config_dir, kind_of: String, default: '/etc/raddb'
attribute :kafka_topic, kind_of: String, default: 'rb_radius'
attribute :name, kind_of: String, default: 'localhost'
attribute :ip, kind_of: String, default: '127.0.0.1'
attribute :flow_nodes, kind_of: Array, default: []
attribute :mode, kind_of: String, default: 'manager'
