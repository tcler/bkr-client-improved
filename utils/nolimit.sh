#!/bin/bash

if [ -n "$1" ]; then
	sed -i 's/#*set permission no/set permission no/' /opt/wub/docroot/*.tml
	echo "limit"
else
	sed -i 's/set permission no/#&/' /opt/wub/docroot/*.tml
	echo "nolimit"
fi
