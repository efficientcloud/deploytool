class DeployTool::Command
  def self.run(command, args)
    DeployTool::Config.load(".deployrc")
    
    if command == "--help"
      puts "Usage:"
      puts "  deploy --add production myapp.heroku.com"
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