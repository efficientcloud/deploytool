class DeployTool::Command
  def self.run(command, args)
    DeployTool::Config.load(".deployrc")
    
    if command == "--help"
      puts "Deploytool Usage Instructions"
      puts ""
      puts "Add a target:"
      puts "  deploy --add production app1@demo.efficientcloud.com"
      puts "  deploy --add staging myapp.heroku.com"
      puts "  deploy --add failover api.cloudfoundry.com"
      puts ""
      puts "Deploy the current directory to the target:"
      puts "  deploy production"
    elsif command == "--add"
      DeployTool::Config[args[0]] = DeployTool::Target.find(args[1]).to_h
    elsif command == "--list"
      puts "Registered Targets:"
      DeployTool::Config.all.each do |target_name, target|
        target = DeployTool::Target.from_config(target)
        puts "  %s\t%s" % [target_name, target.to_s]
      end
    else
      unless (target = DeployTool::Config[command]) && !target.nil? && target.size > 0
        puts "Couldn't find target: #{command}"
        puts "Use --help if you're lost."
        exit
      end
      
      target = DeployTool::Target::EfficientCloud.new(target) # target['type']
      target.push
    end
    
    DeployTool::Config.save
  end
end