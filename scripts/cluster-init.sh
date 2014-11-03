#!/bin/sh

# Usage:
#
# ./cluster-init.sh -n 1 -c "master" -g "http://foo.com/config.json"
#
# Required args:
#   -n number of Sync Gateway nodes to start
#   -c the commit or branch to use.  If "image" is given, will use master branch at time of docker image build.
#   -g the Sync Gateway config file or URL to use.

usage="./cluster-init.sh -n 1 -c \"master\" -g \"http://foo.com/config.json\""

while getopts ":n:u:" opt; do
      case $opt in
        n  ) numnodes=$OPTARG ;;
        c  ) commit=$OPTARG ;;
        g  ) configFileOrURL=$OPTARG ;;
        \? ) echo $usage
             exit 1 ;; 
      esac
done

shift $(($OPTIND - 1))

# make sure required args were given
if [[ -z "$numnodes" || -z "$commit" || -z "$configFileOrURL" ]] ; then
    echo "Missing required args"
    echo "Usage: $usage"
    exit 1 
fi

# validate numnodes argument
re='^[0-9]+$'
if ! [[ $numnodes =~ $re ]] ; then
   echo "error: Not a number" >&2; exit 1
fi

# clone repo with fleet unit files
git clone https://github.com/tleyden/sync-gateway-coreos.git

# generate unit files from template
for i in `seq 1 $NUM_NODES`;
do
    cd sync-gateway-coreos/fleet && cp sync_gw_node.service.template sync_gw_node.$i.service
done

# add values to etcd
etcdctl set /services/sync-gateway/config "$configFileOrURL"
etcdctl set /services/sync-gateway/commit "$commit"

# launch fleet!
fleetctl start sync_gw_node.*.service




