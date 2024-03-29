FROM centos:7

# PostgreSQL image for OpenShift.
# Volumes:
#  * /var/lib/psql/data   - Database cluster for PostgreSQL
# Environment:
#  * $POSTGRESQL_USER     - Database user name
#  * $POSTGRESQL_PASSWORD - User's password
#  * $POSTGRESQL_DATABASE - Name of the database to create
#  * $POSTGRESQL_ADMIN_PASSWORD (Optional) - Password for the 'postgres'
#                           PostgreSQL administrative account

MAINTAINER Tommy Hughes <tchughesiv@gmail.com>

ENV POSTGRESQL_VERSION=9.5 \
    HOME=/var/lib/pgsql \
    PGUSER=postgres

LABEL io.k8s.description="PostgreSQL is an advanced Object-Relational database management system" \
      io.k8s.display-name="PostgreSQL 9.5" \
      io.openshift.expose-services="5432:postgresql" \
      io.openshift.tags="database,postgresql,postgresql95,rh-postgresql95"

EXPOSE 5432

# This image must forever use UID 26 for postgres user so our volumes are
# safe in the future. This should *never* change, the last test is there
# to make sure of that.
RUN yum -y install centos-release-scl && \
    yum -y --setopt=tsflags=nodocs install rh-postgresql95 rh-postgresql95-postgresql-contrib --nogpgcheck && \
    INSTALL_PKGS="rsync tar bind-utils gettext" && \
    yum -y --setopt=tsflags=nodocs install $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all && \
    localedef -f UTF-8 -i en_US en_US.UTF-8 && \
    mkdir -p /var/lib/pgsql/data && \
    test "$(id postgres)" = "uid=26(postgres) gid=26(postgres) groups=26(postgres)"

# Loosen permission bits to avoid problems running container with arbitrary UID
ADD root /
RUN /usr/libexec/fix-permissions /var/lib/pgsql && \
    /usr/libexec/fix-permissions /var/run/postgresql

# Get prefix path and path to scripts rather than hard-code them in scripts
ENV CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/postgresql \
    ENABLED_COLLECTIONS=rh-postgresql95

# When bash is started non-interactively, to run a shell script, for example it
# looks for this variable and source the content of this file. This will enable
# the SCL for all scripts without need to do 'scl enable'.
ENV BASH_ENV=${CONTAINER_SCRIPTS_PATH}/scl_enable \
    ENV=${CONTAINER_SCRIPTS_PATH}/scl_enable \
    PROMPT_COMMAND=". ${CONTAINER_SCRIPTS_PATH}/scl_enable"

RUN echo "host    all             all             0.0.0.0/0               md5" > /var/lib/pgsql/data/pg_hba.conf
RUN echo "local   all             postgres                                    peer" >> /var/lib/pgsql/data/pg_hba.conf

VOLUME ["/var/lib/pgsql"]

#Create Postgres user
RUN groupadd -r postgresql && \
    useradd -g postgresql -d ${HOME} -s /bin/bash -c "PostgreSQL user" postgresql && \
    chown -R postgresql:postgresql ${HOME}

RUN chgrp -R 0 ${HOME} && \
    chmod -R g=u ${HOME} && \
    chmod 777 -R /var/lib/pgsql/data/

USER postgres

ENTRYPOINT ["container-entrypoint"]
CMD ["run-postgresql"]
