class DeployTool::Command
  COMMANDS = ["to", "logs", "import", "export", "config"]
  
  def self.run(command, args)
    DeployTool::Config.load(".deployrc")
    
    if command == "help"
      puts "Deploytool Usage Instructions"
      puts ""
      puts "Add a target:"
      puts "  deploy add production app1@demo.efficientcloud.com"
      puts "  deploy add staging myapp.heroku.com"
      puts "  deploy add failover api.cloudfoundry.com"
      puts ""
      puts "Deploy the current directory to the target:"
      puts "  deploy to production"
    elsif command == "add"
      unless target = DeployTool::Target.find(args[1])
        puts "ERROR: Couldn't find provider for target \"#{args[1]}\""
        puts ""
        puts "Use \"deploy help\" if you're lost."
        exit
      end
      DeployTool::Config[args[0]] = target.to_h
    elsif command == "list"
      puts "Registered Targets:"
      DeployTool::Config.all.each do |target_name, target|
        target = DeployTool::Target.from_config(target)
        puts "  %s%s" % [target_name.ljust(15), target.to_s]
      end
    else
      target_name = command == "to" ? args[0] : command
      
      unless (target = DeployTool::Config[target_name]) && !target.nil? && target.size > 0
        puts "ERROR: Couldn't find target: #{target_name}"
        puts ""
        puts "Use \"deploy help\" if you're lost."
        exit
      end
      
      target = DeployTool::Target.from_config(target)
      target.push
    end
    
    DeployTool::Config.save
  rescue Net::HTTPServerException => e
    puts "ERROR: HTTP call returned %s %s" % [e.response.code, e.response.message]
    puts ""
    if target
      puts "Target:"
      target.to_h.each do |k, v|
        next if k.to_sym == :password
        puts "  %s = %s" % [k, v]
      end
    end
    puts ""
    puts "Backtrace:"
    puts "  " + e.backtrace.join("\n  ")
    puts ""
    puts "Response:"
    e.response.each_header do |k, v|
      puts "  %s: %s" % [k, v]
    end
    puts ""
    puts "  " + e.response.body.gsub("\n", "\n  ")
    puts "!!!"
    puts "Please report the above output at http://bit.ly/deploytool-new-issue"
    puts "!!!"
    exit 2
  end
end