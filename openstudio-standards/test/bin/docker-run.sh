#!/bin/bash

apt-get install -y libglu1-mesa libjpeg8 libfreetype6 libdbus-glib-1-2 libfontconfig1 libsm6 libxi6

export CI=true
export CIRCLECI=true
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Install the openstudio-standards gem
cd /openstudio-standards/openstudio-standards
bundle install

# Run a specific set of tests on each node.
# Test groups are defined in the Rakefile.
# Each group must have a total runtime less
# than 2 hrs.
case $CIRCLE_NODE_INDEX in
  0)
    rake test:gem_group_0
    ;;
  1)
    rake test:gem_group_1
    ;;
  2)
    rake test:gem_group_2
    ;;
  3)
    rake test:gem_group_3
    ;;
  *)
esac
