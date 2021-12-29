# Cookbook Name:: rbnmsp
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

    yum_package "redborder-nmsp" do
      action :upgrade
      flush_cache[:before]
    end

    directory config_dir do #/etc/redborder-nmsp
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

    template "/etc/redborder-nmsp/config.yml" do
      source "rb-nmsp_config.yml.erb"
      cookbook "rbnmsp"
      owner "root"
      group "root"
      mode '0644'
      retries 2
      variables(:zk_hosts => hosts, :flow_nodes => flow_nodes,
                :cloudproxy_nodes => proxy_nodes,
                :db_name => psql_name,
                :db_hostname => db_redborder["hostname"],
                :db_pass => psql_password,
                :db_username => psql_user,
                :db_port => psql_port)
      notifies :restart, 'service[redborder-nmsp]', :delayed
      action :create
    end

    template "/etc/redborder-nmsp/sysconfig" do
      source "rb-nmsp_sysconfig.erb"
      cookbook "rbnmsp"
      owner "root"
      group "root"
      mode '0644'
      retries 2
      variables(:memory => memory)
      notifies :restart, 'service[redborder-nmsp]', :delayed
    end

    service "redborder-nmsp" do
      service_name "redborder-nmsp"
      ignore_failure true
      supports :status => true, :reload => true, :restart => true
      action [:enable, :start]
    end

    Chef::Log.info("cookbook redborder-nmsp has been processed.")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :remove do
  begin
    service "redborder-nmsp" do
      service_name "redborder-nmsp"
      supports :status => true, :restart => true, :start => true, :enable => true, :disable => true
      action [:disable, :stop]
    end
    Chef::Log.info("cookbook redborder-nmsp has been processed.")
  rescue => e
    Chef::Log.error(e.message)
  end
end


action :register do #Usually used to register in consul
  begin
    if !node["rb-nmsp"]["registered"]
      query = {}
      query["ID"] = "rb-nmsp-#{node["hostname"]}"
      query["Name"] = "rb-nmsp"
      query["Address"] = "#{node["ipaddress"]}"
      query["Port"] = 443
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
        command "curl http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.set["rb-nmsp"]["registered"] = true
    end
    Chef::Log.info("rb-nmsp service has been registered in consul")
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do #Usually used to deregister from consul
  begin
    if node["rb-nmsp"]["registered"]
      execute 'Deregister service in consul' do
        command "curl http://localhost:8500/v1/agent/service/deregister/rb-nmsp-#{node["hostname"]} &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.set["rb-nmsp"]["registered"] = false
    end
    Chef::Log.info("rb-nmsp service has been deregistered from consul")
  rescue => e
    Chef::Log.error(e.message)
  end
end
