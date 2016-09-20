#!/bin/bash

export CI=true
export CIRCLECI=true
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Go to the correct root folder
cd /openstudio-standards/openstudio-standards

# Run a specific set of tests on each node.
# Test groups are defined in the Rakefile.
# Each group must have a total runtime less
# than 2 hrs.
case $CIRCLE_NODE_INDEX in
  0)
    rake test:gem_group_4
    ;;
  1)
    rake test:gem_group_5
    ;;
  2)
    rake test:gem_group_6
    ;;
  3)
    rake test:gem_group_7
    ;;
  *)
esac
