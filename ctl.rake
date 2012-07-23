namespace :ctl do
  desc "Start a running server; Will kill the previously started server if still running (alias: start)"
  task :run => ['ctl:stop'] do
    app_file = get_app_path
    CMD = "#{@java_cmd} -jar #{app_file} #{@app_opts} start"
    @logger.info "Starting server with #{CMD}"

    process = ChildProcess.build(*CMD.split(" "))
    process.detach = true
    process.io.inherit!
    process.start
    pid = process.pid
    File.open(".nakamura.pid", 'w') {|f| f.write(pid) }
  end

  def get_app_path
    Dir[@app_file].each do |path|
      if !path.end_with? "-sources.jar" then
        return path
      end
    end
    abort("Unable to find application version")
  end

  task :start => 'ctl:run'

  desc "Kill the previously started server"
  task :kill do
    kill(".nakamura.pid")
  end

  desc "Try to gracefully stop the server, kill the process if that fails"
  task :stop do
    if File.exists? '.nakamura.pid'
      app_file = get_app_path
      cmd = "#{@java_cmd} -jar #{app_file} #{@app_opts} stop"
      process = ChildProcess.build(*cmd.split(" "))
      process.io.inherit!
      process.start
      begin
        process.poll_for_exit(60)
        rm ".nakamura.pid"
      rescue ChildProcess::TimeoutError
        process.stop
        kill(".nakamura.pid")
      end
    end
  end

  desc "Check the status of the last known running server (alias: stat)"
  task :status do
    if File.exists? '.nakamura.pid'
      File.open('.nakamura.pid', 'r') do |f|
        pid = f.read
        begin
          Process.kill 0, pid
          @logger.info "pid [#{pid}] is still running."
        rescue
          @logger.info "pid [#{pid}] is no longer valid."
        end
      end
    else
      @logger.info ".nakamua.pid doesn't exist."
    end
  end

  task :stat => 'ctl:status'

  def kill(pidfile, signal="TERM")
    if File.exists?(pidfile)
      File.open(pidfile, "r") do |f|
        pid = f.read.to_i
        begin
          Process.kill(signal, pid)
          @logger.info "Killing pid #{pid}"
          while (sleep 5) do
            begin
              Process.getpgid(pid)
            rescue
              break
            end
          end
        rescue
          @logger.info "Didn't find pid #{pid}"
        end
      end
      rm pidfile
    end
  end
end
