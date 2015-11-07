# -*- coding: utf-8 -*-
#
# Cookbook Name:: mysql02
# Recipe:: default
#
# Copyright 2015, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

execute 'apt-get update' do
  command 'apt-get update'
  ignore_failure true
end

execute 'update-locale' do
  command 'update-locale LANG="ja_JP.UTF-8" LANGUAGE="ja_JP:ja"'
  ignore_failure true
end


%w{
  nmon
  language-pack-ja-base
  language-pack-ja
  mysql-server
  apparmor-utils
}.each do |pkgname|
  package "#{pkgname}" do
    action :install
  end
end


service "mysql" do
  supports :status => true, :start => true, :stop => true, :restart => true
  action :nothing
end

directory "/data1" do
  owner 'mysql'
  group 'mysql'
  mode '0755'
  action :create
end

directory "/data2" do
  owner 'mysql'
  group 'mysql'
  mode '0755'
  action :create
end

directory "/data3" do
  owner 'mysql'
  group 'mysql'
  mode '0755'
  action :create
end

execute "stop_mysql" do
  command "service mysql stop"
  ignore_failure true
  action :run
end

execute "aa-disable_usr.bin.mysqld" do
  command "aa-disable usr.sbin.mysqld"
  ignore_failure true
  action :run
end

execute "aa-enforce_usr.bin.mysqld" do
  command "aa-enforce usr.sbin.mysqld"
  ignore_failure true
  action :nothing
end

template "/etc/apparmor.d/usr.sbin.mysqld" do
  source "usr.sbin.mysqld.erb"
  owner "root"
  group "root"
  mode 0644
  action :create
  notifies :run, "execute[aa-enforce_usr.bin.mysqld]"
end

server_id = node["mysql"]["server_id"]
bin_log   = node["mysql"]["bin_log"]

template "/etc/mysql/my.cnf" do
  source "my.cnf.erb"
  owner "root"
  group "root"
  mode 0644
  variables({
    :server_id => server_id,
    :bin_log   => bin_log,
  })

end


template "/etc/mysql/conf.d/character-set.cnf" do
  source "character-set.cnf.erb"
  owner "root"
  group "root"
  mode 0644
end

template "/etc/mysql/conf.d/engine.cnf" do
  source "engine.cnf.erb"
  owner "root"
  group "root"
  mode 0644
end

template "/etc/mysql/conf.d/mysqld_safe_syslog.cnf" do
  source "mysqld_safe_syslog.cnf.erb"
  owner "root"
  group "root"
  mode 0644
end

# 新データベース領域にセットアップ
execute "mysqL_install_db" do
  command "/usr/bin/mysql_install_db"
  action :run
  only_if {node["mysql"]["role"] == 'master'}
end

execute "start_mysql" do
  command "service mysql start"
  action :run
  only_if {node["mysql"]["role"] == 'master'}
end


# MySQLのルートユーザーにパスワードを設定
root_password = node["mysql"]["root_password"]
template "#{Chef::Config[:file_cache_path]}/secure_install.sql" do
  owner "root"
  group "root"
  mode 0644
  source "secure_install.sql.erb"
  variables({
    :root_password => root_password,
  })
  only_if {node["mysql"]["role"] == 'master'}
end

execute "secure_install" do
  command "/usr/bin/mysql -u root < #{Chef::Config[:file_cache_path]}/secure_install.sql"
  action :run
  only_if "/usr/bin/mysql -u root -e 'show databases;'"
  ignore_failure true
  only_if {node["mysql"]["role"] == 'master'}
end

# copy sshkey
template "/root/.ssh/id_rsa" do
  owner "root"
  group "root"
  mode 0600
  source "id_rsa.erb"
end


# Setup Master
replica_username = node["mysql"]["replica_username"]
replica_password = node["mysql"]["replica_password"]
replica_ipaddr   = node["mysql"]["replica_ip1"]
master_ipaddr    = node["mysql"]["master_ip"]

template "/root/setup_master.sql.tmp" do
  owner "root"
  group "root"
  mode 0644
  source "setup_master.sql.erb"
  variables({
    :username => replica_username,
    :password => replica_password,
  })
  only_if {node["mysql"]["role"] == 'master'}
end

template "/root/start_replica.tmp" do
  owner "root"
  group "root"
  mode 0644
  source "start_replica.tmp.erb"
  variables({
    :username => replica_username,
    :password => replica_password,
    :root_password => root_password,
    :replica_ip => replica_ipaddr,
    :master_ip => master_ipaddr,
  })
  only_if {node["mysql"]["role"] == 'master'}
end

template "/root/data_sync.sh" do
  owner "root"
  group "root"
  mode 0755
  source "data_sync.sh.erb"
  variables({
    :root_password => root_password,
    :replica_ip => replica_ipaddr,
    :root_password => root_password,
  })
  only_if {node["mysql"]["role"] == 'master'}
end







