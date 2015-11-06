#!/bin/bash

export CI=true
export CIRCLECI=true
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# install dependencies and run default rake task
pwd
ls /
ls /root
echo "Home from docker-run.sh:" $HOME
cd /openstudio-standards/openstudio-standards
bundle install 
bundle exec rake
