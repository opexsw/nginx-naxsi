# Cookbook Name:: nginx-naxsi
# Recipe:: default
# Copyright 2015, Opex Software
# All rights reserved - Do Not Redistribute

#apt-get update
execute 'apt-get update' do
  command "sudo apt-get update"
  action :run
end

#install the 'Development tools' package group
%w[build-essential libpcre3 libpcre3-dev openssl libssl-dev unzip].each do |pkg|
  package pkg do
    action :install
  end
end

#download nginx
remote_file "/usr/local/src/#{node['nginx-naxsi']['nginx_tar']}" do
  source "#{node['nginx-naxsi']['nginx_url']}"
  action :create
end

#download naxsi
remote_file "/usr/local/src/#{node['nginx-naxsi']['naxsi_zip']}" do
  source "#{node['nginx-naxsi']['naxsi_url']}"
  action :create
end

#Uncompressing nginx archive
execute 'untar nginx archive' do
  cwd "/usr/local/src"
  command "tar -zxvf #{node['nginx-naxsi']['nginx_tar']}"
  creates "/usr/local/src/nginx-1.9.9"
  action :run
end

#Uncompressing naxsi archive
execute 'unzip naxsi archive' do
  cwd "/usr/local/src"
  command "unzip #{node['nginx-naxsi']['naxsi_zip']}"
  not_if { ::File.exists?("/usr/local/src/naxsi-master") }
  action :run
end

#Compile nginx and naxsi
bash 'compile nginx and naxsi' do
  cwd '/usr/local/src/nginx-1.9.9'
  code <<-EOH
  ./configure --prefix=/etc/nginx \
              --sbin-path=/usr/sbin/nginx \
              --conf-path=/etc/nginx/nginx.conf \
              --add-module=../naxsi-master/naxsi_src/ \
              --error-log-path=/var/log/nginx/error.log \
              --http-log-path=/var/log/nginx/access.log \
              --pid-path=/var/run/nginx.pid \
              --lock-path=/var/run/nginx.lock \
              --http-client-body-temp-path=/var/cache/nginx/client_temp \
              --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
              --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
              --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
              --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
              --user=nginx \
              --group=nginx \
              --with-http_ssl_module \
              --with-http_realip_module \
              --with-http_addition_module \
              --with-http_sub_module \
              --with-http_dav_module \
              --with-http_flv_module \
              --with-http_mp4_module \
              --with-http_gunzip_module \
              --with-http_gzip_static_module \
              --with-http_random_index_module \
              --with-http_secure_link_module \
              --with-http_stub_status_module \
              --with-http_auth_request_module \
              --with-mail \
              --with-mail_ssl_module \
              --with-file-aio \
              --with-ipv6 \
              --with-cc-opt='-O2 -g -pipe -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector \
              --param=ssp-buffer-size=4 -m64 -mtune=generic';
  make;
  make install;
  EOH
  not_if { ::File.exists?('/usr/sbin/nginx') }
end

#create nginx cache directory
directory node['nginx-naxsi']['nginx_cache_dir'] do
  action :create
  recursive true
end

#Copy nginx init file
cookbook_file "/etc/init.d/nginx" do
  source "nginx.init.j2"
  owner "root"
  group "root"
  mode  "0755" 
  action :create
end

#Copy naxsi.rules file
cookbook_file "/etc/nginx/naxsi.rules" do
  source "naxsi.rules.j2"
  owner "root"
  group "root"
  mode  "0644"  
  action :create
end

#Copy naxsi_core.rules file (customized)
cookbook_file "/etc/nginx/naxsi_core.rules" do
  source "naxsi_core.rules.j2"
  owner "root"
  group "root"
  mode  "0644"  
  action :create
end

#Copy ngingx.conf
template "/etc/nginx/nginx.conf" do
  source "nginx.conf.j2.erb"
  variables({
    :hostname => node['nginx-naxsi']['hostname'],
    :backend_server => node['nginx-naxsi']['backend_server'] ,
  })
  owner "root"
  group "root"
  mode  "0644"
end

#Ensure nginx is started and enabled to start at boot.
service 'nginx' do
  action [:enable, :start]
end
