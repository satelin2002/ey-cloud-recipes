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
   when 'm1.small': worker_count = 0
   when 'c1.medium': worker_count =  1
   when 'c1.xlarge': worker_count = 1
   else
      worker_count = 3
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
      
      # QUEUE = demuxer on resque_demux
      if node[:name] == "resque"
         worker_count.times do |count|
            case count 
            when 1
              config_file = "resque_wildcard_demux.conf.erb"
            when 2
              config_file = "resque_wildcard_transcode.conf.erb"
            else
              config_file = "resque_wildcard_download.conf.erb"
            end    
            
            template "/data/#{app}/shared/config/resque_#{count}.conf" do
               owner node[:owner_name]
               group node[:owner_name]
               mode 0644
               source config_file
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
