#!/bin/sh

# You need to remove existing pem keys otherwise the script will crash 
#rm -r $PWD/clusters/smart-workerdemo

'docker run -it  --volume="$(pwd):/usr/local/src" os-standard /bin/bash -c "bundle exec rake library:export_speed"'