class DeployTool::Command
  COMMANDS = ["to", "logs", "import", "export", "config"]
  
  def self.run(command, args)
    change_to_toplevel_dir!
    
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
      if args[0].nil?
        puts "ERROR: Missing target name."
        puts ""
        puts "Use \"deploy help\" if you're lost."
        exit
      end
      if args[1].nil?
        puts "ERROR: Missing target specification."
        puts ""
        puts "Use \"deploy help\" if you're lost."
        exit
      end
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
      args.unshift command unless command == "to"
      target_name = args[0]
      
      unless (target = DeployTool::Config[target_name]) && !target.nil? && target.size > 0
        puts "ERROR: Couldn't find target: #{target_name}"
        puts ""
        puts "Use \"deploy help\" if you're lost."
        exit
      end
      
      opts = {}
      opts[:timing] = true if args.include?("--timing")

      target = DeployTool::Target.from_config(target)
      begin
        exit target.push opts
      rescue => e
        puts e
        exit 2
      end
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
  
  # Tries to figure out if we're running in a subdirectory of the source,
  # and switches to the top-level if that's the case
  def self.change_to_toplevel_dir!
    indicators = [".git", "Gemfile", "LICENSE", "test"]
  
    timeout = 10
    path = Dir.pwd
    begin
      indicators.each do |indicator|
        next unless File.exists?(File.join(path, indicator))
        
        puts "DEBUG: Found correct top-level directory %s, switching working directory." % [path] unless path == Dir.pwd
        Dir.chdir path
        return
      end
    end until (path = File.dirname(path)) == "/" || (timeout -= 1) == 0

    puts "DEBUG: Couldn't locate top-level directory (traversed until %s), falling back to %s" % [path, Dir.pwd]
  end
end
