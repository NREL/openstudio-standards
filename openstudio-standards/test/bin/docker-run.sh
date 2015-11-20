#!/bin/bash

export CI=true
export CIRCLECI=true
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Install the openstudio-standards gem
cd /openstudio-standards/openstudio-standards
bundle install

# Loop through the test files and run
# every nth test, where n is determined
# by the total number of CI nodes and
# the index of this particular node.
# Note: this command is running
# ON EACH NODE.
i=0
files=()
for testfile in $(find test/ -name "test_*.rb" | sort); do
  if [ $(($i % $CIRCLE_NODE_TOTAL)) -eq $CIRCLE_NODE_INDEX ]
  then
    ruby $testfile
  fi
  ((i=i+1))
done
