# Cookbook Name:: rbfreeradius
#
# Provider:: config
#
action :add do
  begin
    config_dir = new_resource.config_dir
    flow_nodes = new_resource.flow_nodes
    proxy_nodes = new_resource.proxy_nodes
    memory = new_resource.memory
    hosts = new_resource.hosts

    yum_package "redborder-freeradius" do
      action :upgrade
      flush_cache[:before]
    end

    directory config_dir do #/etc/redborder-freeradius
      owner "root"
      group "root"
      mode '755'
      action :create
    end

    ##########################nnnnn
    # Retrieve databag data
    ##########################
    db_redborder = Chef::DataBagItem.load("passwords", "db_redborder") rescue db_redborder = {}
    if !db_redborder.empty?
      psql_name = db_redborder["database"]
      psql_user = db_redborder["username"]
      psql_password = db_redborder["pass"]
      psql_port = db_redborder["port"]
    end

    execute "configure_redborder-freeradius" do
      command "pushd /opt/rb/etc/raddb/sites-enabled; ln -s ../sites-available/dynamic-clients ./; popd"
      notifies :restart, "service[redborder-freeradius]", :delayed if manager_services["redborder-freeradius"]
      ignore_failure true
      action :nothing
    end

    template "/etc/redborder-freeradius/radiusd.conf" do
      source "freeradius_radiusd.conf.erb"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed if manager_services["redborder-freeradius"]
    end

    template "/etc/redborder-freeradius/default" do
      source "freeradius_default.erb"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed if manager_services["redborder-freeradius"]
      notifies :run, "execute[configure_freeradius]", :delayed
    end

    template "/etc/redborder-freeradius/inner-tunnel" do
      source "freeradius_inner-tunnel.erb"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed if manager_services["redborder-freeradius"]
    end

    template "/etc/redborder-freeradius/dynamic-clients" do
      source "freeradius_dynamic-clients.erb"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed if manager_services["redborder-freeradius"]
    end

    template "/etc/redborder-freeradius/raw" do
      source "freeradius_modules_raw.erb"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed if manager_services["redborder-freeradius"]
    end

    template "/etc/redborder-freeradius/sql.conf" do
      source "freeradius_sql.conf.erb"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed if manager_services["redborder-freeradius"]
      variables( :db_name_radius => db_radius_secrets["database"], :db_hostname_radius => db_radius_secrets["hostname"], :db_pass_radius => db_radius_secrets['pass'], :db_username_radius => db_radius_secrets['username'], :db_port_radius => db_radius_port, :db_external_radius => db_radius_secrets["external"])
    end

    template "/etc/redborder-freeradius/kafka_log.conf" do
      source "freeradius_kafka_log.conf.erb"
      owner "root"
      group "root"
      mode 0644
      retries 2
      variables(:kafka_managers => managers_per_service["kafka"], :flow_nodes => flow_nodes)
      notifies :restart, "service[redborder-freeradius]", :delayed if manager_services["redborder-freeradius"]
    end

    template "/etc/redborder-freeradius/clients.conf" do
      source "freeradius_clients.conf.erb"
      owner "root"
      group "root"
      mode 0644
      retries 2
      variables(:flow_nodes => flow_nodes)
      notifies :reload, "service[redborder-freeradius]", :delayed if manager_services["redborder-freeradius"]
    end

    service "redborder-freeradius" do
      service_name "redborder-freeradius"
      ignore_failure true
      supports :status => true, :reload => true, :restart => true
      action [:enable, :start]
    end

    Chef::Log.info("cookbook redborder-freeradius has been processed.")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :remove do
  begin
    service "redborder-freeradius" do
      service_name "redborder-freeradius"
      supports :status => true, :restart => true, :start => true, :enable => true, :disable => true
      action [:disable, :stop]
    end
    Chef::Log.info("cookbook redborder-freeradius has been processed.")
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

      node.set["rb-nmsp"]["registered"] = true
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
