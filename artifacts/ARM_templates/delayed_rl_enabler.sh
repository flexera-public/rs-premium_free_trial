#!/bin/sh

# This script schedules the RL enablement and returns a success so that the 
# ARM template extension execution logic is satisfied.
# Otherwise we end up in a dead lock condition where the rightlink.enable.sh script waits until the instance is not in the 
# "pending" state (i.e. not "running") but since the rightlink.enable.sh custom script extension doesn't return, ARM won't
# update the instance to the "running" state. 
#
# So this script schedules RL enablement in the future and returns success.
#
# INPUTS: the command line to pass to rightlink.enable.sh

./rightlink.enable.sh $* | at now +1 minutes >/dev/null 2>&1 

exit 0