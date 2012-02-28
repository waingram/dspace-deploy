### Capistrano deploy for ideals-dspace
###
### Bill Ingram <wingram2@illinois.edu>
### Tue Feb 28 09:58:23 CST 2012

require 'open-uri'

set :application,    "ideals-dspace"
set :env_type,       "dev"

set :scm, :subversion
set :repository,     "https://track.library.uiuc.edu/svn/ideals-dspace/trunk"

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
set :java_mirror,    "http://download.oracle.com/otn-pub/java/jdk/6u31-b04/jdk-6u31-linux-x64.bin"
set :jdk_version,    "jdk1.6.0_31"
set :java_home,      "#{service_root}/java"
set :jdk_home,       "#{java_home}/jdk"
set :jre_home,       "#{jdk_home}/jre"
set :jsse_home,      "#{jre_home}/lib"
set :java_opts,      "-Dhttps.protocols=SSLv3"

# Maven
set :maven_tarball,  "apache-maven-2.2.1-bin.tar.gz"
set :maven_mirror,   "http://apache.deathculture.net//maven/binaries/apache-maven-2.2.1-bin.tar.gz"
set :maven_version,  "apache-maven-2.2.1"
set :maven_home,     "#{service_root}/maven"
set :maven_opts,     "-Xms256M -Xmx512M -Dfile.encoding=UTF-8"
set :mvn_profiles,   "all,ideals-test"
set :skip_tests,     "true"

# Ant
set :ant_tarball,    "apache-maven-2.2.1-bin.tar.gz"
set :ant_mirror,     "http://apache.deathculture.net//maven/binaries/apache-maven-2.2.1-bin.tar.gz"
set :ant_version,    "apache-maven-2.2.1"
set :ant_home,       "#{service_root}/ant"

# Tomcat
set :catalina_home,  "#{service_root}/tomcat"
set :catalina_opts,  "-server -Xms512M -Xmx1024M -Dfile.encoding=UTF-8"
set :tomcat_tarball, "apache-tomcat-6.6-bin.tar.gz"
set :tomcat_mirror,  "http://apache./tomcat/binaries/apache-tomcat-6.6-bin.tar.gz"
set :tomcat_version, "apache-tomcat-6.6"
set :tomcat_home,    "#{catalina_home}"

# Postgres
set :pg_home,        "#{service_root}/pgsql"
set :pg_data,        "#{pg_home}/databases"
set :pg_host,        "#{pg_home}/run"

# DSpace
set :dspace_version, "1.6.2"
set :dspace_home,    "#{service_root}/dspace"
set :dspace_source,  "#{deploy_to}"
set :dspace_db_user, "dspace"
set :dspace_db_name, "dspace"

###
### Cold Deploy
### 

namespace :prep do
  desc 'Initializes the service directory'
  task :init, :roles => :app do
    run "echo '#{service_email}' | #{service_root}/.forward"
    run "mkdir #{service_root}/tmp"
    run "chmod 755 #{service_root}/tmp"
    file = File.join(File.dirname(__FILE__), 'templates', 'bashrc.erb')
    template = File.read(file)
    buffer = ERB.new(template).result(binding)
    put buffer, "#{service_root}/.bashrc", :mode => 0600
  end

  desc 'Install Java JDK'
  task :install_java, :roles => :app do
    run "mkdir -p #{java_home}"

    # Delete any old files
    run "cd #{java_home} && rm -rf *.*"
    
    logger.info "web download #{java_mirror}" if logger
    buffer = open(java_mirror).read
    put buffer, "#{java_home}/#{java_binary}", :mode => 0755
    
    run "cd #{java_home} && echo 'yes' '\n' | ./#{java_binary} 1>/dev/null"
    run "cd #{java_home} && ln -s #{jdk_version} jdk"
    run "cd #{java_home} && rm -f #{java_binary}"
  end
  
  desc 'Install Maven'
  task :install_maven, :roles => :app do
    install_tarball maven_home, maven_mirror, maven_tarball, maven_filename
  end
    
  desc 'Install Ant'
  task :install_ant, :roles => :app do
    install_tarball ant_home, ant_mirror, ant_tarball, ant_filename
  end

  desc 'Install Tomcat'
  task :install_tomcat, :roles => :app do
    install_tarball tomcat_home, tomcat_mirror, tomcat_tarball, tomcat_filename
  end

  desc 'Install PostgreSQL'
  task :install_postgresql, :roles => :db do
    
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
  
end

def install_tarball dir, mirror, tarball, filename
  run "mkdir -p #{dir}"

  # Delete any old files
  run "cd #{dir} && rm -rf *.*"
  
  logger.info "web download #{mirror}" if logger
  buffer = open(mirror).read
  put buffer, "#{service_root}/#{file}", :mode => 0755
  
  run "cd #{service_root} && tar xzvf #{file} 1>/dev/null"
  run "cd #{service_root} && mv #{name} #{dir}"
  run "cd #{service_root} && rm -f #{file}"
end


def remote_file_exists? remote_path
  'true' ==  capture("if [ -e #{remote_path} ]; then echo 'true'; fi").strip
end

before 'prep:install_postgresql', 'tomcat:stop', 'postgres:stop'
after 'prep:install_postgresql', 'postgres:start', 'tomcat:start'

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

namespace :postgres do
  
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
    run "cd #{deploy_to}/current/dspace/target/dspace-#{dspace_version}-build.dir && JAVA_HOME=#{java_home} #{ant_home}/bin/ant fresh-install"
  end
  
  desc "Update DSpace with Ant"
  task :update, :roles=>[:app] do
    run "cd #{deploy_to}/current/dspace/target/dspace-#{dspace_version}-build.dir && JAVA_HOME=#{java_home} #{ant_home}/bin/ant update"
  end
  
end


namespace :deploy do
  
  desc "Makes the latest release group writeable"
  task :finalize_update, :except => { :no_release => true } do
    run "chmod -R g+w #{latest_release}" if fetch(:group_writable, true)
  end

  desc "Restart Postgres and Tomcat"
  task :restart, :roles=>[:app,:db] do
    postgres.stop
    tomcat.stop
    tomcat.clean
    postgres.start
    tomcat.start
  end
  
end

after 'deploy:update', 'dspace:build', 'dspace:update'

###
### Unused tasks
###

#
# Disable all the default tasks that
# either don't apply, or I haven't made work.
#
namespace :deploy do
  [ :upload, :cold, :start, :stop, :migrate, :migrations ].each do |default_task|
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
