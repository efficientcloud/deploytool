class DeployTool::Command
  def self.run(command, args)
    DeployTool::Config.load(".deployrc")
    
    if command == "--help"
      puts "Usage:"
      puts "  deploy --add production myapp.heroku.com"
      puts "  deploy production"
    elsif command == "--add"
      DeployTool::Config[args[0]] = DeployTool::Target.find(args[1]).to_h
    elsif command == "--dummy"
    else
      unless (target = DeployTool::Config[command]) && !target.nil? && target.size > 0
        puts "Couldn't find target: #{command}"
        puts "Use --help if you're lost."
        exit
      end
      
      target = DeployTool::Target::Heroku.new(target) # target['type']
      target.push
    end
    
    DeployTool::Config.save
  end
end