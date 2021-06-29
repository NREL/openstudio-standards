# AUTHOR:  Anton Szilasi
# DESCRIPTION:  Docker build for running Rakefile in this repo across different OS versions
# OpenStudio/ruby set up taken from - https://github.com/NREL/docker-openstudio/blob/master/Dockerfile

# Pull base image.
FROM nrel/openstudio:3.1.0

MAINTAINER Anton Szilasi ajszilasi@gmail.com

WORKDIR /usr/local/src

# Install bundler
RUN gem install bundle

CMD [ "/bin/bash" ]