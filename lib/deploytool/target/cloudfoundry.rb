class DeployTool::Target::CloudFoundry < DeployTool::Target
  def self.matches?(target_spec)
    # Test through multiple versions of API server URLs
    [target_spec, 'api.' + target_spec, 'api.' + target_spec.split('.', 2).last].each do |api_server|
      begin
        return true if get_json_resource("http://%s/info" % api_server)['name'] == "vcap"
      rescue => e
        $logger.debug "Exception: %s\n%s" % [e.message, e.backtrace.join("\n")]
      end
    end
    false
  end
  
  def initialize(options)
    # FIXME
  end
  
  def self.create(target_spec)
    app_name, api_server = target_spec.split('.', 2)
    CloudFoundry.new('api_server' => api_server, 'app_name' => app_name)
  end
end