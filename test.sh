
#!/bin/bash

i=0
files=()
for testfile in $(find openstudio-standards/ -name "test_*.rb" | sort); do
  if [ $(($i % $CIRCLE_NODE_TOTAL)) -eq $CIRCLE_NODE_INDEX ]
  then
    docker run -v $(pwd):/openstudio-standards nrel/openstudio ruby $testfile
  fi
  ((i=i+1))
done
