# -*- coding: utf-8 -*-
#
# Cookbook Name:: mysql02
# Recipe:: default
#
# Copyright 2016, IBM
# All rights reserved 
#
# MySQL 5.6 コミュニティ・エディションをダウンロード
# マスター＆レプリカでセットアップする
#

work_dir = '/root/mysql'
conf_dir = '/etc/mysql'
#ubuntu_ver = '5.6.27-1ubuntu14.04_amd64'
ubuntu_ver = '5.6.28-1ubuntu14.04_amd64'
#centos6_ver = '5.6.27-1.el6.x86_64'
centos6_ver = '5.6.28-1.el6.x86_64'
#centos7_ver = '5.6.27-1.el7.x86_64'
centos7_ver = '5.6.28-1.el7.x86_64'

#
# パッケージ導入 Ubuntu,CentOS/Redhat
#
case node['platform']

when 'ubuntu'
  execute 'apt-get update' do
    command 'apt-get update'
  end

  # 前提パッケージ
  package 'apparmor-utils'
  package 'libaio1'

  # https://dev.mysql.com/downloads/mysql/ のサイトからMySQLのtarファイルのURLを拾って指定
  tar_url = "http://dev.mysql.com/get/Downloads/MySQL-5.6/mysql-server_#{ubuntu_ver}.deb-bundle.tar"

when 'centos','redhat'
  execute 'yum update' do
    command 'yum update -y'
    action :run
  end

  # 前提パッケージ
  package 'wget'
  package 'libaio'

  # https://dev.mysql.com/downloads/mysql/ のサイトからMySQLのtarファイルのURLを拾って指定
  case node['platform_version'].to_i
    when 6
      tar_url = "http://dev.mysql.com/get/Downloads/MySQL-5.6/MySQL-#{centos6_ver}.rpm-bundle.tar"
    when 7
      package 'net-tools'
      tar_url = "http://dev.mysql.com/get/Downloads/MySQL-5.6/MySQL-#{centos7_ver}.rpm-bundle.tar"
  end
end

#
# MySQL tarファイルの取得と展開
#
script "install_mysql" do
  interpreter "bash"
  user        "root"
  code <<-EOL
     # rm -fr /etc/my.cnf /etc/my.cnf.d #{conf_dir}
     mkdir #{conf_dir}
     mkdir #{work_dir}
     wget -P #{work_dir} #{tar_url}
     cd #{work_dir}
     tar xvf `ls *.tar`
  EOL
  action :run
end


#
# MySQL Serverのインストール
#
case node['platform']
when 'ubuntu'
  dpkg_package "#{work_dir}/mysql-common_#{ubuntu_ver}.deb"
  dpkg_package "#{work_dir}/mysql-community-server_#{ubuntu_ver}.deb"
  dpkg_package "#{work_dir}/mysql-community-client_#{ubuntu_ver}.deb"
when 'centos','redhat'
  case node['platform_version'].to_i
    when 6
      # 依存関係のあるモジュール postfix以下のコマンドは実行できない。
      #rpm_package "mysql-libs-5.1.73-5.el6_6.x86_64" do
      #  action :remove
      #end
      execute "delete mysql-libs-5.1.73-5.el6_6.x86_64" do
        #command "rpm -e --nodeps mysql-libs-5.1.73-5.el6_6.x86_64"
        command "rpm -e --nodeps mysql-libs"
        action :run
        ignore_failure true
      end
      # パッケージのインストール
      rpm_package "#{work_dir}/MySQL-shared-#{centos6_ver}.rpm" 
      rpm_package "#{work_dir}/MySQL-shared-compat-#{centos6_ver}.rpm" 
      rpm_package "#{work_dir}/MySQL-server-#{centos6_ver}.rpm"
      rpm_package "#{work_dir}/MySQL-client-#{centos6_ver}.rpm"

    when 7
      # 依存関係のあるモジュール postfix以下のコマンドは実行できない。
      #rpm_package "mariadb-libs-5.5.44-1.el7_1.x86_64" do
      #  action :remove
      #end
      execute "delete mariadb-libs" do
        #command "rpm -e --nodeps mariadb-libs-5.5.44-1.el7_1.x86_64"
        command "rpm -e --nodeps mariadb-libs"
        action :run
        ignore_failure true
      end

      rpm_package "#{work_dir}/MySQL-shared-#{centos7_ver}.rpm" 
      rpm_package "#{work_dir}/MySQL-shared-compat-#{centos7_ver}.rpm"
      rpm_package "#{work_dir}/MySQL-server-#{centos7_ver}.rpm"
      rpm_package "#{work_dir}/MySQL-client-#{centos7_ver}.rpm"
  end
end


#
# MySQLの自動起動と停止を設定
#
service "mysql" do
  supports :start => true, :stop => true
  action :nothing
end

service "mysql_enable" do
  service_name 'mysql'
  action :enable
  only_if {node["mysql"]["service"] == 'enable'}
end



#========================
#
# コンテナ領域を新規作成
#
#========================
directory "/data1" do
  owner 'mysql'
  group 'mysql'
  mode '0755'
  action :create
  notifies :stop, "service[mysql]", :immediately
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

#=============================

case node['platform']
#
# Ubuntu の AppArmor アプリ アーマーの設定
#
when 'ubuntu','debian'
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
    notifies :run, "execute[aa-enforce_usr.bin.mysqld]"
  end

#
# CentOS/RedHat は設定ファイルの置き場作成
#
when 'centos','redhat'
  directory "/etc/mysql" do
    owner "root"
    group "root"
    mode '0755'
    action :create
  end
  directory "/etc/mysql/conf.d" do
    owner "root"
    group "root"
    mode '0755'
    action :create
  end
  directory "/var/log/mysql" do
    owner "mysql"
    group "mysql"
    mode '0755'
    action :create
  end

end # case

#
# MySQL設定ファイルの配置
#
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

#===========================

#
# 先の設定ファイルが指すコンテナ領域に
# MySQLのコンテナ、ログ等を作成する
#
# 共有ディスクにセットアップする事を想定して
# この設定が動作するのは、master ノードの場合のみで
# replica ノードの場合には、実行しない。
#
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


#
# secure_install.sql を実行してパスワードを設定
#
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


#
# データベースを作成
#
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







