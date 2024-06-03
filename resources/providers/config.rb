# Cookbook:: freeradius
# Provider:: config

action :config_common do
  begin
    mode = new_resource.mode
    config_dir = new_resource.config_dir
    flow_nodes = new_resource.flow_nodes

    dnf_package 'freeradius-rb' do
      action :upgrade
      flush_cache[:before]
    end

    dnf_package 'freeradius-rb-kafka' do
      action :upgrade
      flush_cache[:before]
    end

    dnf_package 'freeradius-rb-krb5' do
      action :upgrade
      flush_cache[:before]
    end

    dnf_package 'freeradius-rb-ldap' do
      action :upgrade
      flush_cache[:before]
    end

    dnf_package 'freeradius-rb-mysql' do
      action :upgrade
      flush_cache[:before]
    end

    dnf_package 'freeradius-rb-perl' do
      action :upgrade
      flush_cache[:before]
    end

    dnf_package 'freeradius-rb-postgresql' do
      action :upgrade
      flush_cache[:before]
    end

    dnf_package 'freeradius-rb-python' do
      action :upgrade
      flush_cache[:before]
    end

    dnf_package 'freeradius-rb-unixODBC' do
      action :upgrade
      flush_cache[:before]
    end

    dnf_package 'freeradius-rb-utils' do
      action :upgrade
      flush_cache[:before]
    end

    dnf_package 'rbutils' do
      action :upgrade
      flush_cache[:before]
    end

    directory config_dir do # /etc/raddb
      owner 'root'
      group 'root'
      mode '755'
      action :create
    end

    # Templates
    template "#{config_dir}/radiusd.conf" do
      source 'freeradius_radiusd.conf.erb'
      cookbook 'freeradius'
      owner 'root'
      group 'root'
      mode '0644'
      retries 2
      variables(mode: mode)
      notifies :restart, 'service[radiusd]', :delayed
    end

    template "#{config_dir}/sites-available/default" do
      source 'freeradius_default.erb'
      cookbook 'freeradius'
      owner 'root'
      group 'root'
      mode '0644'
      retries 2
      variables(mode: mode)
      notifies :run, 'execute[configure_freeradius-rb]', :delayed
      notifies :restart, 'service[radiusd]', :delayed
    end

    execute 'configure_freeradius-rb' do
      command 'pushd etc/raddb/sites-enabled; ln -s ../sites-available/dynamic-clients ./; popd'
      notifies :restart, 'service[radiusd]', :delayed
      ignore_failure true
      action :nothing
    end

    template "#{config_dir}/kafka_log.conf" do
      source 'freeradius_kafka_log.conf.erb'
      cookbook 'freeradius'
      owner 'root'
      group 'root'
      mode '0644'
      retries 2
      variables(flow_nodes: flow_nodes, mode: mode)
      notifies :restart, 'service[radiusd]', :delayed
    end

    template "#{config_dir}/clients.conf" do
      source 'freeradius_clients.conf.erb'
      cookbook 'freeradius'
      owner 'root'
      group 'root'
      mode '0644'
      retries 2
      variables(flow_nodes: flow_nodes, mode: mode)
      notifies :reload, 'service[radiusd]', :delayed
    end

    # end of templates

    service 'radiusd' do
      service_name 'radiusd'
      ignore_failure true
      supports status: true, reload: true, restart: true
      action [:enable, :start]
    end

    Chef::Log.info('Common cookbook freeradius configuration has been processed.')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :config_manager do
  config_dir = new_resource.config_dir

  # Retrieve databag data
  begin
    db_radius_secrets = data_bag_item('passwords', 'db_radius')
  rescue
    db_radius_secrets = {}
  end

  unless db_radius_secrets.empty?
    db_name_radius = db_radius_secrets['database']
    db_username_radius = db_radius_secrets['username']
    db_pass_radius = db_radius_secrets['pass']
    db_port_radius = db_radius_secrets['port']
    db_hostname_radius = db_radius_secrets['hostname']
    db_external_radius = db_radius_secrets['external']
  end

  bash 'creating_radius_tables' do
    code <<-EOH
      /bin/psql -U #{db_username_radius} -h #{db_hostname_radius} -p #{db_port_radius} \
                                         -f #{config_dir}/sql/postgresql/nas.sql
      /bin/psql -U #{db_username_radius} -h #{db_hostname_radius} -p #{db_port_radius} \
                                         -f #{config_dir}/sql/postgresql/schema.sql
    EOH
    only_if do
      shell_out('/bin/psql', '-U', "#{db_username_radius}", '-h', "#{db_hostname_radius}",
                '-p', "#{db_port_radius}", '-t', '-c', "SELECT 'nas'::regclass;").error? ||
        shell_out('/bin/psql', '-U', "#{db_username_radius}", '-h', "#{db_hostname_radius}",
                '-p', "#{db_port_radius}", '-t', '-c', "SELECT 'radacct'::regclass;").error?
    end
  end

  template "#{config_dir}/sql.conf" do
    source 'freeradius_sql.conf.erb'
    cookbook 'freeradius'
    owner 'root'
    group 'root'
    mode '0644'
    retries 2
    notifies :restart, 'service[radiusd]', :delayed
    variables(db_name_radius: db_name_radius, db_hostname_radius: db_hostname_radius,
              db_pass_radius: db_pass_radius, db_username_radius: db_username_radius,
              db_port_radius: db_port_radius, db_external_radius: db_external_radius)
  end

  template "#{config_dir}/modules/raw" do
    source 'freeradius_modules_raw.erb'
    cookbook 'freeradius'
    owner 'root'
    group 'root'
    mode '0644'
    retries 2
    notifies :restart, 'service[radiusd]', :delayed
  end

  template "#{config_dir}/sites-available/inner-tunnel" do
    source 'freeradius_inner-tunnel.erb'
    cookbook 'freeradius'
    owner 'root'
    group 'root'
    mode '0644'
    retries 2
    notifies :restart, 'service[radiusd]', :delayed
  end

  template "#{config_dir}/sites-available/dynamic-clients" do
    source 'freeradius_dynamic-clients.erb'
    cookbook 'freeradius'
    owner 'root'
    group 'root'
    mode '0644'
    retries 2
    notifies :restart, 'service[radiusd]', :delayed
  end

  service 'radiusd' do
    service_name 'radiusd'
    ignore_failure true
    supports status: true, reload: true, restart: true
    action [:enable, :start]
  end

  Chef::Log.info('Manager cookbook freeradius configuration has been processed.')
end

action :remove do
  begin
    service 'radiusd' do
      service_name 'radiusd'
      supports status: true, restart: true, start: true, enable: true, disable: true
      action [:disable, :stop]
    end
    Chef::Log.info('cookbook freeradius has been processed.')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :register do
  begin
    unless node['freeradius']['registered']
      query = {}
      query['ID'] = "freeradius-#{node['hostname']}"
      query['Name'] = 'freeradius'
      query['Address'] = "#{node['ipaddress']}"
      query['Port'] = 1812
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.normal['freeradius']['registered'] = true
    end
    Chef::Log.info('freeradius service has been registered in consul')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do
  begin
    if node['freeradius']['registered']
      execute 'Deregister service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/deregister/freeradius-#{node['hostname']} &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.normal['freeradius']['registered'] = false
    end
    Chef::Log.info('freeradius service has been deregistered from consul')
  rescue => e
    Chef::Log.error(e.message)
  end
end
