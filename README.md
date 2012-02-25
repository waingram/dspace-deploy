# DSpace Deploy

Capistrano tasks for deploying DSpace. Includes `deploy:cold` recipe,
which will set up a service directory, install Java, Tomcat, Ant and
Maven, and create the database in PostgreSQL.

## Why?

Because I've set up DSpace too many times.

## Caveats 

The installation assumes you are installing the whole stack in a
*service directory* as a *service user*, which is the way our campus
IT requires us to do it. Everything in the *service directory* is owned by the
*service user* (_e.g._, `~/java/`, `~/maven/`, `~/tomcat`, _etc_, _etc_).
Apache and Postgres are owned by *root*, so their configuration is not
covered here. We are responsible for our own database, though, which
lives at `~/pgsql` (_i.e._, while *root* owns the database _server_,
the *service user* owns the database _itself_).

All of this should be easy to change and customize to your
environment. 

## Usage

    > cap -T
    cap deploy                 # Deploys your project.
    cap deploy:check           # Test deployment dependencies.
    cap deploy:cleanup         # Clean up old releases.
    cap deploy:finalize_update # Makes the latest release group writeable
    cap deploy:restart         # Restart Postgres and Tomcat
    cap deploy:rollback        # Rolls back to a previous version and restarts.
    cap deploy:rollback:code   # Rolls back to the previously deployed version.
    cap deploy:setup           # Prepares one or more servers for deployment.
    cap deploy:symlink         # Updates the symlink to the most recently deploye...
    cap deploy:update          # Copies your project and updates the symlink.
    cap deploy:update_code     # Copies your project to the remote servers.
    cap dspace:build           # Build dspace with maven
    cap dspace:deploy          # Deploy DSpace with Ant
    cap dspace:update          # Update DSpace with Ant
    cap invoke                 # Invoke a single command on the remote servers.
    cap postgres:start         # Start PostgreSQL
    cap postgres:stop          # Stop PostgreSQL
    cap prep:init              # Initializes the service directory
    cap prep:install_java      # Install Java JDK
    cap prep:install_maven     # Install Maven
    cap shell                  # Begin an interactive     Capistrano session.
    cap tomcat:clean           # Clean Tomcat cache
    cap tomcat:restart         # Restart Tomcat
    cap tomcat:start           # Start Tomcat
    cap tomcat:stop            # Stop Tomcat
    cap tomcat:tail            # Tail tomcat/logs/catalina.out

