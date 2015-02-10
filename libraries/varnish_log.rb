class Chef
  class Resource
    # Configure Varnish logging.
    class VarnishLog < Chef::Resource::LWRPBase
      resource_name :varnish_log
      actions :configure
      default_action :configure

      attribute :name, kind_of: String, name_attribute: true
      attribute :file_name, kind_of: String, default: '/var/log/varnish/varnishlog.log'
      attribute :pid, kind_of: String, default: '/var/run/varnishlog.pid'
      attribute :log_format, kind_of: String, default: 'varnishlog',
                             equal_to: ['varnishlog', 'varnishncsa']
      attribute :ncsa_format_string, kind_of: String,
                                     default: '%h|%l|%u|%t|\"%r\"|%s|%b|\"%{Referer}i\"|\"%{User-agent}i\"'
      attribute :instance_name, kind_of: String,
                                default: nil
    end
  end

  class Provider
    # Configure Varnish logging.
    class VarnishLog < Chef::Provider::LWRPBase
      include VarnishCookbook::Helpers
      use_inline_resources

      def whyrun_supported?
        true
      end

      def action_configure
        configure_varnish_log
      end

      def configure_varnish_log
        template "/etc/default/#{new_resource.log_format}" do
          if node['platform_family'] == 'debian'
            path "/etc/default/#{new_resource.log_format}"
            source 'lib_varnishlog.erb'
          elsif node['init_package'] == 'systemd'
            path "/etc/systemd/system/#{new_resource.log_format}.params"
            source 'lib_varnishlog_systemd.erb'
          else
            path "/etc/sysconfig/#{new_resource.log_format}"
            source 'lib_varnishlog.erb'
          end
          cookbook 'varnish'
          owner 'root'
          group 'root'
          mode '0644'
          variables(
            config: new_resource,
            varnish_version: varnish_version
          )
          action :create
          notifies :restart, "service[#{new_resource.log_format}]", :delayed
        end

        service new_resource.log_format do
          supports restart: true, reload: true
          # varnish and varnishlog services sometimes enter a race condition.
          restart_command "sleep 5 && service #{new_resource.log_format} restart"
          action %w(enable start)
        end
      end
    end
  end
end