### Capistrano deploy for ideals-dspace
###
### Bill Ingram <wingram2@illinois.edu>
### Tue Feb 28 09:58:23 CST 2012

require 'open-uri'

set :application,    "ideals-dspace"
set :env_type,       "dev"

set :scm, :git
set :repository,     "git@bitbucket.org:UIUCLibrary/ideals-dspace.git"

server               "luk.cites.illinois.edu", :app, :db, :primary => true

set :deploy_via, :copy
set :copy_strategy, :export

set :user,           "ideals-dspace"
set :group,          "ideals-dspace"

#set :service_root,  "/services/#{application}/tmp/#{application}"
set :service_root,   "/services/#{application}"
set :service_email,  "ideals-admin@illinois.edu"

depend :remote, :directory, service_root

set :deploy_to,      "#{service_root}/src/#{application}"
set :use_sudo,       false

# Java
set :java_binary,    "jdk-6u31-linux-x64.bin"
## Oracle no longer allows direct downloads of Java, so you have to manually
## download it to your desktop first. Grr. 
## set :java_mirror,    "http://download.oracle.com/otn-pub/java/jdk/6u31-b04/jdk-6u31-linux-x64.bin"
set :java_mirror,    "/home/wingram2/Downloads/jdk-6u31-linux-x64.bin"
set :jdk_filename,   "jdk1.6.0_31"
set :java_root,      "#{service_root}/java"
set :java_home,       "#{java_root}/jdk"
set :jre_home,       "#{java_home}/jre"
set :jsse_home,      "#{jre_home}/lib"
set :java_opts,      "-Dhttps.protocols=SSLv3"

# Maven
set :maven_tarball,  "apache-maven-2.2.1-bin.tar.gz"
set :maven_mirror,   "http://apache.deathculture.net//maven/binaries/apache-maven-2.2.1-bin.tar.gz"
set :maven_filename,  "apache-maven-2.2.1"
set :maven_home,     "#{service_root}/maven"
set :maven_opts,     "-Xms256M -Xmx512M -Dfile.encoding=UTF-8"
set :mvn_profiles,   "all,ideals-test"
set :skip_tests,     "true"

# Ant
set :ant_tarball,    "apache-maven-2.2.1-bin.tar.gz"
set :ant_mirror,     "http://apache.deathculture.net//maven/binaries/apache-maven-2.2.1-bin.tar.gz"
set :ant_filename,    "apache-maven-2.2.1"
set :ant_home,       "#{service_root}/ant"

# Tomcat
set :catalina_home,  "#{service_root}/tomcat"
set :catalina_opts,  "-server -Xms512M -Xmx1024M -Dfile.encoding=UTF-8"
set :tomcat_tarball, "apache-tomcat-6.0.35.tar.gz"
set :tomcat_mirror,  "http://www.reverse.net/pub/apache/tomcat/tomcat-6/v6.0.35/bin/apache-tomcat-6.0.35.tar.gz"
set :tomcat_filename, "apache-tomcat-6.0.35"
set :tomcat_home,    "#{catalina_home}"

# Postgres
set :pg_home,        "#{service_root}/pgsql"
set :pg_data,        "#{pg_home}/databases"
set :pg_host,        "#{pg_home}/run"

# DSpace
set :dspace_filename, "1.6.2"
set :dspace_home,    "#{service_root}/dspace"
set :dspace_source,  "#{deploy_to}"
set :dspace_db_user, "dspace"
set :dspace_db_name, "dspace"

# ClamAV
set :clamav_home,    "#{service_root}/clamav"

###
### Cold Deploy
### 

namespace :prep do
  desc 'Initializes the service directory'
  task :init, :roles => :app do
    run "umask 022"
    run "touch #{service_root}/.forward && echo '#{service_email}' > #{service_root}/.forward"
    run "touch #{service_root}/.bash_profile && echo '. ~/.bashrc' >> #{service_root}/.bash_profile"
    run "mkdir -p #{service_root}/tmp #{service_root}/bin"
    file = File.join(File.dirname(__FILE__), 'templates', 'bashrc.erb')
    template = File.read(file)
    buffer = ERB.new(template).result(binding)
    put buffer, "#{service_root}/.bashrc", :mode => 0600
  end

  namespace :java do
    desc 'Install Java JDK'
    task :install, :roles => :app do
      run "mkdir -p #{java_home}"

      # Delete any old files
      run "cd #{java_home} && rm -rf *"
      
      logger.info "web download #{java_mirror}" if logger
      buffer = open(java_mirror).read
      put buffer, "#{java_home}/#{java_binary}", :mode => 0755
      
      run "cd #{java_home} && echo 'yes' '\n' | ./#{java_binary} 1>/dev/null"
      run "cd #{java_home} && ln -s #{jdk_filename} jdk"
      run "cd #{java_home} && rm -f #{java_binary}"
    end
  end

  namespace :maven do
    desc 'Install Maven'
    task :install, :roles => :app do
      install_tarball maven_home, maven_mirror, maven_tarball, maven_filename
    end
  end

  namespace :ant do
    desc 'Install Ant'
    task :install_ant, :roles => :app do
      install_tarball ant_home, ant_mirror, ant_tarball, ant_filename
    end
  end

  namespace :tomcat do
    desc 'Install Tomcat'
    task :install, :roles => :app do
      install_tarball tomcat_home, tomcat_mirror, tomcat_tarball, tomcat_filename
    end

    desc 'Configure Tomcat'
    task :config, :roles => :app do
      file = File.join(File.dirname(__FILE__), 'templates', 'server.xml.erb')
      template = File.read(file)
      buffer = ERB.new(template).result(binding)
      run "mv #{tomcat_home}/conf/server.xml #{tomact_home}/conf/server.xml.original"
      put buffer, "#{tomcat_home}/conf/server.xml", :mode => 0600
    end
  end

  namespace :pg do
    desc 'Install PostgreSQL'
    task :install, :roles => :db do
      
      backup = remote_file_exists? "#{pg_data}"   # try to back up any existing database
      p backup
      if backup
        stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
        run "cd #{service_root} && PGDATA=#{pg_data} PGHOST=#{pg_host} pg_dumpall -o > tmp/postgres.#{stamp}.out"
        run "cd #{service_root} && mv #{pg_data} tmp/pg_data.#{stamp}.old"
      end
      run "cd #{service_root} && initdb -D #{pg_data}"
      if backup
        run "cd #{service_root} && PGDATA=#{pg_data} PGHOST=#{pg_host} psql -d template1 -f tmp/postgres.#{stamp}.out"
      end
    end

    desc 'Configure PostgreSQL'
    task :config, :roles => :db do
      run "cd #{pg_home} && mkdir -p log run"
      run "mv #{pg_data}/postgresql.conf #{pg_data}/postgresql.conf.pre"
      file = File.join(File.dirname(__FILE__), 'templates', 'postgresql.conf.erb')
      template = File.read(file)
      buffer = ERB.new(template).result(binding)
      put buffer, "#{pg_data}/postgresql.conf", :mode => 0600
    end
  end
  
end


# Helper function for installing Tomcat, Maven, and Ant -- same pattern
# 
# +dir+::      Target directory for the installation, e.g., ~/tomcat
# +mirror+::   Download mirror URL, e.g., http://apache.org/tomact/apache-tomcat-6.0.35.tar.gz
# +tarball+::  File name of the downloaded tarball, e.g., apache-tomcat-6.0.35.tar.gz
# +filename+:: Name of the directory resulting from un-taring the tarball, e.g., apache-tomcat-6.0.35
def install_tarball dir, mirror, tarball, filename
  
  # Delete any existing installation
  run "rm -rf #{dir}"
  
  logger.info "web download #{mirror}" if logger
  buffer = open(mirror).read
  put buffer, "#{service_root}/#{tarball}", :mode => 0755
  
  run "cd #{service_root} && tar xzvf #{tarball} 1>/dev/null"
  run "cd #{service_root} && mv #{filename} #{dir}"
  run "cd #{service_root} && rm -rf #{filename}"
  run "cd #{service_root} && rm -f #{tarball}"
end

# Helper funtion to check is a file exists on the server
#
# +remote_path+:: Full path to the file in question
def remote_file_exists? remote_path
  'true' ==  capture("if [ -e #{remote_path} ]; then echo 'true'; fi").strip
end

# Some before and after hooks for cold deploy
before 'prep:pg:install',     'tomcat:stop', 'pg:stop'
after  'prep:pg:install',     'prep:pg:config'
after  'prep:tomcat:install', 'prep:tomcat:config'


###
### Regular Deploy (Upgrade)
###

namespace :tomcat do

  desc "Start Tomcat"
  task :start, :roles => [:app] do
    run "#{service_root}/bin/start-tomcat"
  end
  
  desc "Stop Tomcat"
  task :stop, :roles => [:app]  do
    begin
      run "#{service_root}/bin/stop-tomcat"
    rescue RuntimeError => e
      # skip it
    end
  end

  desc "Clean Tomcat cache"
  task :clean, :roles => [:app]  do
    run "#{service_root}/bin/clean-tomcat"    
  end    

  desc "Restart Tomcat"
  task :restart, :roles => [:app]  do
    run "#{service_root}/bin/restart-tomcat"
  end

  desc "Tail tomcat/logs/catalina.out"
  task :tail, :roles => [:app]  do
    stream "tail -f #{tomcat_home}/logs/catalina.out"
  end
  
end

namespace :pg do
  
  desc "Start PostgreSQL"
  task :start, :roles => [:db] do
    run "#{service_root}/bin/start-postgres"
  end

  desc "Stop PostgreSQL"
  task :stop, :roles => [:db] do
    begin
      run "#{service_root}/bin/stop-postgres"
    rescue RuntimeError => e
      # skip it
    end
  end
  
  desc 'Backup DB'
  task :backup_dspace_db, :roles => :db do
    stamp = Time.now.utc.strftime("%Y%m%d%H%M.%S")
    run "cd #{service_root} && PGDATA=#{pg_data} PGHOST=#{pg_host} pg_dump -E UNICODE -f tmp/dspace-data.#{stamp} #{dspace_db_name}"
    run "cd #{service_root}/tmp && gzip -9 dspace-data.#{stamp}"
  end
  
end

namespace :dspace do

  desc 'Create dspace DB user'
  task :create_db_user, :roles => :db do
    run "cd #{service_root} && PGDATA=#{pg_data} PGHOST=#{pg_host} createuser -dSRP #{dspace_db_user}"
  end

  desc 'Create dspace DB'
  task :create_db, :roles => :db do
    run "cd #{service_root} && PGDATA=#{pg_data} PGHOST=#{pg_host} createdb -U #{dspace_db_user} -E UNICODE #{dspace_db_name}"
  end
  
  desc "Build dspace with maven"
  task :build, :roles=>[:app] do
    run "cd #{deploy_to}/current/dspace && JAVA_HOME=#{java_home} MAVEN_OPTS=\"#{maven_opts}\" #{maven_home}/bin/mvn -P #{mvn_profiles} -DskipTests=#{skip_tests} clean package"
  end

  desc "Deploy DSpace with Ant"
  task :deploy, :roles=>[:app] do
    run "cd #{deploy_to}/current/dspace/target/dspace-#{dspace_filename}-build.dir && JAVA_HOME=#{java_home} #{ant_home}/bin/ant fresh-install"
  end
  
  desc "Update DSpace with Ant"
  task :update, :roles=>[:app] do
    run "cd #{deploy_to}/current/dspace/target/dspace-#{dspace_filename}-build.dir && JAVA_HOME=#{java_home} #{ant_home}/bin/ant update"
  end
  
end


namespace :deploy do
  
  desc "Makes the latest release group writeable"
  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
  end

  desc "Restart Postgres and Tomcat"
  task :restart, :roles=>[:app,:db] do
    pg.stop
    tomcat.stop
    tomcat.clean
    pg.start
    tomcat.start
  end
  
end

# Some before and after hooks for regular deploy
after 'deploy:update', 'dspace:build', 'dspace:update'


###
### Unused tasks
###

#
# Disable all the default tasks that
# either don't apply, or I haven't made work.
#
namespace :deploy do
  [ :upload, :start, :stop, :migrate, :migrations ].each do |default_task|
    desc "[internal] disabled"
    task default_task do
      # disabled
    end
  end

  namespace :web do
    [ :disable, :enable ].each do |default_task|
      desc "[internal] disabled"
      task default_task do
        # disabled
      end
    end
  end

  namespace :pending do
    [ :default, :diff ].each do |default_task|
      desc "[internal] disabled"
      task default_task do
        # disabled
      end
    end
  end
end
