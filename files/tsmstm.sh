#!/bin/sh

INITFILE=/etc/init.d/tsmstm
SERVICE_PID_FILE=/var/run/tsmstm.pid
APP=$0

usage() {
    echo "Usage: $APP [ COMMAND ]"
    doexit
}
callinit() {
    [ -x $INITFILE ] || {
        echo "No init file '$INITFILE'"
        return
    }
    exec $INITFILE $1
    RETVAL=$?
}
run() {
    exec /usr/bin/lua /usr/lib/lua/tsmstm/app.lua
    RETVAL=$?
}

doexit() {
    exit $RETVAL
}

[ -n "$INCLUDE_ONLY" ] && return

CMD="$1"
[ -z $CMD ] && {
    run
    doexit
}
shift
# See how we were called.
case "$CMD" in
    start|stop|restart|reload)
        callinit $CMD
        ;;
    *)
        RETVAL=1
        usage $0
        ;;
esac

doexit
