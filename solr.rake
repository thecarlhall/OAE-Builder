#
# solr namepsace - tasks related to setting up a local Solr server.
#
namespace :solr do
  SOLR_SRC_ROOT = File.join(@nakamura['path'], 'bundles', 'solr')

  SOLR_VERSION = ENV['solr_version'] || '4.0.0-ALPHA'
  SOLR_BASENAME = "solr-#{SOLR_VERSION}"
  SOLR_FILENAME = "#{SOLR_BASENAME}.war"
  SOLR_DOWNLOAD_HOST = ENV['solr_download_host'] || 'central.maven.org'
  SOLR_DOWNLOAD_URL = ENV['solr_download_url'] || "/maven2/org/apache/solr/solr/#{SOLR_VERSION}/#{SOLR_FILENAME}"

  JETTY_VERSION = ENV['jetty_version'] || '8.1.5.v20120716'
  JETTY_BASENAME = "jetty-distribution-#{JETTY_VERSION}"
  JETTY_FILENAME = "#{JETTY_BASENAME}.zip"
  JETTY_DOWNLOAD_HOST = ENV['jetty_download_host'] || 'download.eclipse.org'
  JETTY_DOWNLOAD_URL = ENV['jetty_download_url'] || "/jetty/#{JETTY_VERSION}/dist/#{JETTY_FILENAME}"
  JETTY_PORT = 8983

  ## ========== Internal functions =============================================
  #
  # Download a remote file from a host to a local file
  #
  def download_file(host, remote_file, local_file)
    require 'net/http'
    Net::HTTP.start(host) do |http|
      resp = http.get(remote_file)
      open(local_file, "w") { |file| file.write(resp.body) }
    end
  end

  #
  # Unzip a file to a destination
  #
  def unzip_file(filename, destination)
    require 'zipruby'
    require 'fileutils'
    Zip::Archive.open(filename) do |ar|
      ar.each do |zf|
        zip_name = File.join(destination, zf.name)
        if zf.directory?
          FileUtils.mkdir_p(zip_name)
        else
          dirname = File.dirname(zip_name)
          FileUtils.mkdir_p(dirname) unless File.exist?(dirname)

          open(zip_name, 'wb') do |f|
            f << zf.read
          end
        end
      end
    end
  end

  ## ========== Tasks ==========================================================
  desc "Start the Solr server"
  task :start do
    if File.exists? JETTY_BASENAME
      CMD = "env JETTY_PORT=#{JETTY_PORT} #{JETTY_BASENAME}/bin/jetty.sh start"
      @logger.info "Starting Solr server with #{CMD}"

      process = ChildProcess.build(*CMD.split(" "))
      process.detach = true
      process.io.inherit!
      process.start
    else
      @logger.info "Jetty installation not found in #{JETTY_BASENAME}. Run `rake solr:setup`."
    end
  end

  desc "Stop the Solr server"
  task :stop do
    if File.exists? JETTY_BASENAME
      CMD = "env JETTY_PORT=#{JETTY_PORT} #{JETTY_BASENAME}/bin/jetty.sh stop"
      @logger.info "Stopping Solr server with #{CMD}"

      process = ChildProcess.build(*CMD.split(" "))
      process.detach = true
      process.io.inherit!
      process.start
    else
      @logger.info "Jetty installation not found in #{JETTY_BASENAME}. Run `rake solr:setup`."
    end
  end
  
  desc "Download and configure Solr to run as a standalone server using Jetty."
  task :download => 'solr:download:jetty' do
    unless File.exists? SOLR_FILENAME
      @logger.info "Downloading Solr v#{SOLR_VERSION}"
      download_file SOLR_DOWNLOAD_HOST,
        SOLR_DOWNLOAD_URL, SOLR_FILENAME
    else
      @logger.info "Found the Solr artifact already downloaded [#{SOLR_FILENAME}]."
    end

    # unzip the solr war into jetty
    ENV['solr_webapp'] = solr_webapp = "jetty-distribution-#{JETTY_VERSION}/webapps/solr"
    unless File.exists? solr_webapp
      @logger.info "Unzipping solr webapp"
      unzip_file SOLR_FILENAME, solr_webapp
    else
      @logger.info "Found the Solr webapp already deployed to Jetty [#{solr_webapp}]."
    end
  end

  desc "Setup a local Solr webapp with Nakamura configuration and dependencies."
  task :setup => ['solr:download'] do
    unless File.exists? "#{JETTY_BASENAME}"
      @logger.info "Unable to find Jetty distribution [#{JETTY_BASENAME}]. rake solr:download:jetty can fix that."
      return
    end

    # create shell file to start solr with -Dsolr.solr.home="#{JETTY_BASENAME}/webapps/solr/conf"
    solr_dir = "#{JETTY_BASENAME}/solr"
    FileUtils.mkdir solr_dir unless File.exists? solr_dir

    # copy the config files and dependencies to the solr webapp
    @logger.info "Copying configuration files to #{solr_dir}."
    artifact_basename = File.join(SOLR_SRC_ROOT, 'src', 'main', 'resources', '.')
    FileUtils::cp_r artifact_basename, solr_dir

    # copy o.s.n.solr artifact to webapps/solr/WEB-INF/lib
    solr_webapp_lib = "#{ENV['solr_webapp']}/WEB-INF/lib"
    solr_artifact = File.join(SOLR_SRC_ROOT, 'target', 'org.sakaiproject.nakamura.solr-*.jar')
    Dir.glob(solr_artifact) do |filename|
      if filename !~ /sources/
        @logger.info "Copying #{filename} to #{solr_webapp_lib}"
        FileUtils.cp filename, solr_webapp_lib
      end
    end

    @logger.info "====================================================="
    @logger.info "| Start Solr with:"
    @logger.info "|   rake solr:start"
    @logger.info "|  OR"
    @logger.info "|   cd #{JETTY_BASENAME}"
    @logger.info "|   ./bin/jetty.sh start"
    @logger.info "-----------------------------------------------------"
    @logger.info "| When starting the Solr server outside of #{JETTY_BASENAME}, use this JVM param:"
    @logger.info "|   -Dsolr.solr.home=#{File.expand_path(JETTY_BASENAME)}/solr"
    @logger.info "====================================================="
  end

  #
  # download namespace - tasks for downloading artifacts ancillary to Solr.
  #
  namespace :download do
    desc "Download jetty-distribution-#{JETTY_VERSION}.tar.gz."
    task :jetty do
      # download the jetty archive
      unless File.exists? JETTY_FILENAME or File.exists? JETTY_BASENAME
        @logger.info "Downloading Jetty v#{JETTY_VERSION}"
        download_file JETTY_DOWNLOAD_HOST,
          JETTY_DOWNLOAD_URL,
          JETTY_FILENAME
      else
        @logger.info "Found the Jetty artifact [#{JETTY_FILENAME}] or the unzipped results of the artifact [#{JETTY_BASENAME}]."
      end

      # unzip the jetty archive
      if File.exists? JETTY_FILENAME and not File.exists? JETTY_BASENAME
        @logger.info "Unzipping Jetty distribution"
        unzip_file JETTY_FILENAME, '.'
      else
        @logger.info "Found the Jetty artifact already unarchived in this folder [#{JETTY_BASENAME}]."
      end
    end
  end
end
