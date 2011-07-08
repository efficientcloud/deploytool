class DeployTool::Target::CloudFoundry < DeployTool::Target
  def self.parse_target_spec(target_spec)
    app_name, server = target_spec.split('.', 2)
    return false if server.nil? or app_name.nil?
    # Test through multiple versions of API server URLs
    [target_spec, 'api.' + target_spec, 'api.' + server].each do |api_server|
      begin
        if get_json_resource("http://%s/info" % api_server)['name'] == "vcap"
          app_name = nil if server.gsub('api.') == api_server.gsub('api.')
          return [app_name, api_server]
        end
      rescue => e
        $logger.debug "Exception: %s\n%s" % [e.message, e.backtrace.join("\n")]
      end
    end
    false
  end
  
  def self.matches?(target_spec)
    return true if parse_target_spec(target_spec)
  end
  
  def initialize(options)
    # FIXME
  end
  
  def self.create(target_spec)
    app_name, api_server = parse_target_spec(target_spec)
    CloudFoundry.new('api_server' => api_server, 'app_name' => app_name)
  end
end
