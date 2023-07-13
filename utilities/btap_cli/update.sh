#!/usr/bin/env bash
if [ -z "$STANDARDS_BRANCH" ]; then STANDARDS_BRANCH=nrcan; fi
sed -i '/^.*standards.*$/d' Gemfile
echo "gem 'openstudio-standards', :github => 'NREL/openstudio-standards', :branch => '$STANDARDS_BRANCH'" | tee -a Gemfile
bundle update openstudio-standards
