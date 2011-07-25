#
# Cookbook Name:: resque
# Recipe:: default
#
if ['solo', 'util'].include?(node[:instance_role])

   execute "install resque gem" do
      command "gem install resque redis redis-namespace yajl-ruby -r"
      not_if { "gem list | grep resque" }
   end

   case node[:ec2][:instance_type]
   when 'm1.small': worker_count = 2
   when 'c1.medium': worker_count = 3
   when 'c1.xlarge': worker_count = 8
   else
      worker_count = 2
   end


   node[:applications].each do |app, data|
      template "/etc/monit.d/resque_#{app}.monitrc" do
         owner 'root'
         group 'root'
         mode 0644
         source "monitrc.conf.erb"
         variables({
            :num_workers => worker_count,
            :app_name => app,
            :rails_env => node[:environment][:framework_env]
         })
      end
      
      
      ### START 
      ## Insert a downloader QUEUE for the application instance.
      # Added name "resque_download" manually in /etc/chef/dna.json
      # 
      # 
      if node[:instance_role] == "solo"
         worker_count.times do |count|
            template "/data/#{app}/shared/config/resque_#{count}.conf" do
               owner node[:owner_name]
               group node[:owner_name]
               mode 0644
               source "resque_wildcard_download.conf.erb"
            end
         end
      end
      
      # QUEUE = transcoder on resque_transcode
      if node[:name] == "resque_transcode"
         worker_count.times do |count|
            template "/data/#{app}/shared/config/resque_#{count}.conf" do
               owner node[:owner_name]
               group node[:owner_name]
               mode 0644
               source "resque_wildcard_transcode.conf.erb"
            end
         end
      end
      
      # QUEUE = demuxer on resque_demux
      if node[:name] == "resque_demux"
         worker_count.times do |count|
            template "/data/#{app}/shared/config/resque_#{count}.conf" do
               owner node[:owner_name]
               group node[:owner_name]
               mode 0644
               source "resque_wildcard_demux.conf.erb"
            end
         end
      end
      
      ### END

      execute "ensure-resque-is-setup-with-monit" do
         command %Q{
            monit reload
         }
      end

      execute "restart-resque" do
         command %Q{
            echo "sleep 20 && monit -g #{app}_resque restart all" | at now
         }
      end
   end
end
