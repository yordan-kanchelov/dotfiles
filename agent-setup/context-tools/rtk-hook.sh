#!/bin/sh
if [ "${RTK_DISABLED:-0}" = "1" ]; then
  exit 0
fi
exec rtk hook "$@"
