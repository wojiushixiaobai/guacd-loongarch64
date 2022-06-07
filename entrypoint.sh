#!/bin/bash
#

if [ ! "$GUACD_LOG_LEVEL" ]; then
    export GUACD_LOG_LEVEL=error
fi

/usr/local/guacamole/sbin/guacd -b 0.0.0.0 -L $GUACD_LOG_LEVEL -f
