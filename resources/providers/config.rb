# Cookbook Name:: rbfreeradius
#
# Provider:: config
#
action :add do
  begin
    config_dir = new_resource.config_dir
    flow_nodes = new_resource.flow_nodes

    yum_package "redborder-freeradius" do
      action :upgrade
      flush_cache[:before]
    end

    directory config_dir do #/etc/raddb
      owner "root"
      group "root"
      mode '755'
      action :create
    end

    #radius
    db_radius_secrets = nil
    if !node["redBorder"]["manager"]["externals"].nil? and !node["redBorder"]["manager"]["externals"]["postgresql"].nil? and !node["redBorder"]["manager"]["externals"]["postgresql"]["radius"].nil?
      db_radius_secrets=node["redBorder"]["manager"]["externals"]["postgresql"]["radius"] if node["redBorder"]["manager"]["externals"]["postgresql"]["radius"]["enabled"] == true
    end
    begin
      db_radius_secrets = Chef::EncryptedDataBagItem.load("passwords", "db_radius") if db_radius_secrets.nil?
    rescue
      db_radius_secrets = {}
    end
    db_radius_port = (db_radius_secrets["port"].nil? ? 5432 : db_radius_secrets["port"].to_i)


    execute "configure_redborder-freeradius" do
      command "pushd etc/raddb/sites-enabled; ln -s ../sites-available/dynamic-clients ./; popd"
      notifies :restart, "service[redborder-freeradius]", :delayed if manager_services["redborder-freeradius"]
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
      notifies :restart, "service[redborder-freeradius]", :delayed
    end

    template "/etc/raddb/sites-available/default" do
      source "freeradius_default.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed
      notifies :run, "execute[configure_redborder-freeradius]", :delayed
    end

    template "/etc/raddb/sites-available/inner-tunnel" do
      source "freeradius_inner-tunnel.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed
    end

    template "/etc/raddb/sites-available/dynamic-clients" do
      source "freeradius_dynamic-clients.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed
    end

    template "/etc/raddb/modules/raw" do
      source "freeradius_modules_raw.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed
    end

    template "/etc/raddb/sql.conf" do
      source "freeradius_sql.conf.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      notifies :restart, "service[redborder-freeradius]", :delayed
      variables( :db_name_radius => db_radius_secrets["database"], :db_hostname_radius => db_radius_secrets["hostname"], :db_pass_radius => db_radius_secrets['pass'], :db_username_radius => db_radius_secrets['username'], :db_port_radius => db_radius_port, :db_external_radius => db_radius_secrets["external"])
    end

    template "/etc/raddb/kafka_log.conf" do
      source "freeradius_kafka_log.conf.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      variables(:kafka_managers => managers_per_service["kafka"], :flow_nodes => flow_nodes)
      notifies :restart, "service[redborder-freeradius]", :delayed
    end

    template "/etc/raddb/clients.conf" do
      source "freeradius_clients.conf.erb"
      cookbook "rbfreeradius"
      owner "root"
      group "root"
      mode 0644
      retries 2
      variables(:flow_nodes => flow_nodes)
      notifies :reload, "service[redborder-freeradius]", :delayed
    end

    #end of templates

    service "redborder-freeradius" do
      service_name "redborder-freeradius"
      ignore_failure true
      supports :status => true, :reload => true, :restart => true
      manager_services["redborder-freeradius"] ? action([:start, :enable]) : action([:stop, :disable])
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
