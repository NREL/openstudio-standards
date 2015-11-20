#!/bin/bash

export CI=true
export CIRCLECI=true
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# install dependencies and run default rake task
cd /openstudio-standards/openstudio-standards
bundle install

echo "In the docker container, then ENV variables are:"
printenv
ruby -v

i=0
files=()
for testfile in $(find test/ -name "test_*.rb" | sort); do
  if [ $(($i % $CIRCLE_NODE_TOTAL)) -eq $CIRCLE_NODE_INDEX ]
  then
    ruby $testfile
  fi
  ((i=i+1))
done
