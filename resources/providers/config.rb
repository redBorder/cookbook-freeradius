# Cookbook Name:: rbfreeradius
#
# Provider:: config
#
action :add do
  begin
    config_dir = new_resource.config_dir
    flow_nodes = new_resource.flow_nodes

    yum_package "freeradius-rb" do
      action :upgrade
      flush_cache[:before]
    end

    yum_package "freeradius-rb-kafka" do
      action :upgrade
      flush_cache[:before]
    end

    yum_package "freeradius-rb-krb5" do
      action :upgrade
      flush_cache[:before]
    end

    yum_package "freeradius-rb-ldap" do
      action :upgrade
      flush_cache[:before]
    end

    yum_package "freeradius-rb-mysql" do
      action :upgrade
      flush_cache[:before]
    end

    yum_package "freeradius-rb-perl" do
      action :upgrade
      flush_cache[:before]
    end

    yum_package "freeradius-rb-postgresql" do
      action :upgrade
      flush_cache[:before]
    end

    yum_package "freeradius-rb-python" do
      action :upgrade
      flush_cache[:before]
    end

    yum_package "freeradius-rb-unixODBC" do
      action :upgrade
      flush_cache[:before]
    end

    yum_package "freeradius-rb-utils" do
      action :upgrade
      flush_cache[:before]
    end

    directory config_dir do #/etc/raddb
      owner "root"
      group "root"
      mode '755'
      action :create
    end

    ##########################
    # Retrieve databag data
    ##########################
    db_radius_secrets = Chef::DataBagItem.load("passwords", "db_radius_secrets") rescue db_radius_secrets = {}
    if !db_radius_secrets.empty?
      db_name_radius = db_radius_secrets["database"]
      db_username_radius = db_radius_secrets["username"]
      db_pass_radius = db_radius_secrets["pass"]
      db_port_radius = db_radius_secrets["port"]
      db_hostname_radius = db_radius_secrets["hostname"]
      db_external_radius = db_radius_secrets["external"]
    end


    execute "configure_freeradius-rb" do
      command "pushd etc/raddb/sites-enabled; ln -s ../sites-available/dynamic-clients ./; popd"
      notifies :restart, "service[radiusd]", :delayed
      ignore_failure true
      action :nothing
    end

    #Templates

    template "/etc/raddb/radiusd.conf" do
      source "freeradius_radiusd.conf.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[radiusd]", :delayed
    end

    template "/etc/raddb/sites-available/default" do
      source "freeradius_default.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed
      notifies :run, "execute[configure_freeradius-rb]", :delayed
    end

    template "/etc/raddb/sites-available/inner-tunnel" do
      source "freeradius_inner-tunnel.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[radiusd]", :delayed
    end

    template "/etc/raddb/sites-available/dynamic-clients" do
      source "freeradius_dynamic-clients.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[radiusd]", :delayed
    end

    template "/etc/raddb/modules/raw" do
      source "freeradius_modules_raw.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[radiusd]", :delayed
    end

    template "/etc/raddb/sql.conf" do
      source "freeradius_sql.conf.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[radiusd]", :delayed
      variables( :db_name_radius => db_name_radius, :db_hostname_radius => db_hostname_radius, :db_pass_radius => db_pass_radius, :db_username_radius => db_username_radius, :db_port_radius => db_port_radius, :db_external_radius => db_external_radius)
    end

    template "/etc/raddb/kafka_log.conf" do
      source "freeradius_kafka_log.conf.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      variables(:flow_nodes => flow_nodes)
      notifies :restart, "service[radiusd]", :delayed
    end

    template "/etc/raddb/clients.conf" do
      source "freeradius_clients.conf.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      variables(:flow_nodes => flow_nodes)
      notifies :reload, "service[radiusd]", :delayed
    end

    #end of templates

    service "radiusd" do
      service_name "radiusd"
      ignore_failure true
      supports :status => true, :reload => true, :restart => true
      action [:enable, :start]
    end

    Chef::Log.info("cookbook freeradius has been processed.")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :remove do
  begin
    service "radiusd" do
      service_name "radiusd"
      supports :status => true, :restart => true, :start => true, :enable => true, :disable => true
      action [:disable, :stop]
    end
    Chef::Log.info("cookbook freeradius has been processed.")
  rescue => e
    Chef::Log.error(e.message)
  end
end


action :register do #Usually used to register in consul
  begin
    if !node["rb-freeradius"]["registered"]
      query = {}
      query["ID"] = "rb-freeradius-#{node["hostname"]}"
      query["Name"] = "rb-freeradius"
      query["Address"] = "#{node["ipaddress"]}"
      query["Port"] = 1812
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
        command "curl http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.set["rb-freeradius"]["registered"] = true
    end
    Chef::Log.info("rb-freeradius service has been registered in consul")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do #Usually used to deregister from consul
  begin
    if node["rb-freeradius"]["registered"]
      execute 'Deregister service in consul' do
        command "curl http://localhost:8500/v1/agent/service/deregister/rb-freeradius-#{node["hostname"]} &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.set["rb-freeradius"]["registered"] = false
    end
    Chef::Log.info("rb-freeradius service has been deregistered from consul")
  rescue => e
    Chef::Log.error(e.message)
  end
end
