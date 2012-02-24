# DSpace Deploy

Capistrano tasks for deploying DSpace. Includes `deploy:cold` recipe,
which will set up a service directory, install Java, Tomcat, Ant and
Maven, and create the database in PostgreSQL.

## Why?

Because I've set up DSpace too many times.

## Caveats 

The installation assumes you are installing the whole stack in a
_service directory_ as a _service user_, which is the way our campus
IT requires us to do it. For example, our server will have a directory
called `/services/ideals-dspace` that is owned by the `ideals-dspace`
user account. Everything in the _service directory_ is owned by the
_service user_ (_e.g._, `~/java/`, `~/maven/`, `~/tomcat`, etc, etc).
However, Apache and Postgres are owned by `root`. There is a `~/pgsql/`
directory in the _service directory_ owned by the _service user_ which
contains our database, but the actual database server is owned by
`root`. All of this should be easy to change and customize to your
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

