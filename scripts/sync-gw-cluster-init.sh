#!/bin/sh


# Args:
#   -n number of Sync Gateway nodes to start
#   -c the commit or branch to use.  If "image" is given, will use master branch at time of docker image build.
#   -b the name of the couchbase bucket to create, or leave this off if you don't need to create a bucket.  (optional)
#   -z the size of the bucket in megabytes, or leave this off if you don't need to create a bucket.  (optional)
#   -g the Sync Gateway config file or URL to use.
#   -v Couchbase Server version (3.0.1 or 2.2, or 0 to skip the couchbase server initialization)
#   -m number of couchbase nodes to start
#   -u the username and password as a single string, delimited by a colon (:)

usage="./sync-gw-cluster-init.sh -n 1 -c \"master\" -b \"todolite\" -z \"512\" -g \"http://foo.com/config.json\" -v 3.0.1 -m 3 -u \"user:passw0rd\""

function untilsuccessful() {
	"$@"
	while [ $? -ne 0 ]; do
		echo Retrying...
		sleep 1
		"$@"
	done
}

while getopts ":n:c:g:b:z:v:m:u:" opt; do
      case $opt in
        s  ) startcbs=$OPTARG ;;
        n  ) numnodes=$OPTARG ;;
        c  ) commit=$OPTARG ;;
        b  ) bucket=$OPTARG ;;
        z  ) bucket_size=$OPTARG ;;
        g  ) configFileOrURL=$OPTARG ;;
        v  ) version=$OPTARG ;;
        m  ) num_cb_nodes=$OPTARG ;;
        u  ) userpass=$OPTARG ;;
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

if [ "$version" != "0" ]; then

    # parse user/pass into variables
    IFS=':' read -a array <<< "$userpass"
    CB_USERNAME=${array[0]}
    CB_PASSWORD=${array[1]}

    # Kick off couchbase cluster 
    echo "Kick off couchbase cluster"
    wget https://raw.githubusercontent.com/couchbaselabs/couchbase-server-docker/support/0.3/scripts/cluster-init.sh
    chmod +x cluster-init.sh
    ./cluster-init.sh -v $version -n $num_cb_nodes -u $userpass

    if [ $? -ne 0 ]; then
	echo "Error executing cluster-init.sh"
	exit 1 
    fi

fi

# wait until all couchbase nodes come up (have at least numnodes in etcd)
echo "Wait until $num_cb_nodes Couchbase Servers running"
NUM_COUCHBASE_SERVERS="0"
while (( $NUM_COUCHBASE_SERVERS != $num_cb_nodes )); do
    echo "Retrying... $NUM_COUCHBASE_SERVERS != $num_cb_nodes"
    NUM_COUCHBASE_SERVERS=$(etcdctl ls /couchbase.com/couchbase-node-state | wc -l)
    sleep 5
done
echo "Done waiting: $num_cb_nodes Couchbase Servers are running"

# ie "/couchbase.com/couchbase-node-state/10.153.232.237"
FIRST_NODE=$(etcdctl ls /couchbase.com/couchbase-node-state | sed -n 1p)

if [[ -z "$FIRST_NODE" ]] ; then
    echo "No couchbase nodes found in etcd"
    exit 1
fi

# ie, "10.153.232.237"
COUCHBASE_CLUSTER=$(echo $FIRST_NODE | awk -F/ '{ print $4 }')

if [[ -z "$COUCHBASE_CLUSTER" ]] ; then
    echo "Could not find ip of couchbase cluster node"
    exit 1
fi


if [ "$version" != "0" ]; then

    # rebalance cluster
    untilsuccessful sudo docker run tleyden5iwx/couchbase-server-$version /opt/couchbase/bin/couchbase-cli rebalance -c $COUCHBASE_CLUSTER -u $CB_USERNAME -p $CB_PASSWORD

    # create bucket
    if [ -z "$bucket" ]; then
	echo "No bucket specified, not creating one"
    else 
	echo "Create a bucket: $bucket with size: $bucket_size"
	untilsuccessful sudo docker run tleyden5iwx/couchbase-server-$version /opt/couchbase/bin/couchbase-cli bucket-create -c $COUCHBASE_CLUSTER -u $CB_USERNAME -p $CB_PASSWORD --bucket=$bucket --bucket-ramsize=$bucket_size
	echo "Done: created a bucket"
    fi

fi


# add values to etcd
etcdctl set /couchbase.com/sync-gateway/config "$configFileOrURL"
etcdctl set /couchbase.com/sync-gateway/commit "$commit"

# clone repo with fleet unit files
git clone https://github.com/tleyden/sync-gateway-coreos.git
cd sync-gateway-coreos
git checkout -t origin/support/0.3
cd ..

# register fleet untit files
cd sync-gateway-coreos/fleet && fleetctl submit *.service

# generate unit files from template
for i in `seq 1 $numnodes`;
do
   fleetctl start sync_gw_node@$i.service && fleetctl start sync_gw_announce@$i.service
done

echo "Your couchbase server + sync gateway cluster is now active!"
