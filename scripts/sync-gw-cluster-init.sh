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

usage="./sync-gw-cluster-init.sh -n 1 -c \"master\" -b "todolite" -z "512" -g \"http://foo.com/config.json\" -v 3.0.1 -m 3 -u \"user:passw0rd\""

function untilsuccessful() {
	"$@"
	while [ $? -ne 0 ]; do
		echo Retrying...
		sleep 1
		"$@"
	done
}

while getopts ":n:c:g:" opt; do
      case $opt in
        n  ) numnodes=$OPTARG ;;
        m  ) num_cb_nodes=$OPTARG ;;
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

if 

if [ "$version" != "0" ]; then

    # Kick off couchbase cluster 
    echo "Kick off couchbase cluster"
    wget https://raw.githubusercontent.com/couchbaselabs/couchbase-server-docker/master/scripts/cluster-init.sh
    chmod +x cluster-init.sh
    ./cluster-init.sh -v $version -n $num_cb_nodes -u $userpass

    if [ $? -ne 0 ]; then
	echo "Error executing cluster-init.sh"
	exit 1 
    fi

    # Wait until bootstrap node is up
    echo "Wait until Couchbase bootstrap node is up"
    while [ -z "$COUCHBASE_CLUSTER" ]; do
	echo Retrying...
	COUCHBASE_CLUSTER=$(etcdctl get /services/couchbase/bootstrap_ip)
	sleep 5
    done

    echo "Couchbase Server bootstrap ip: $COUCHBASE_CLUSTER"

    # wait until all couchbase nodes come up
    echo "Wait until $numnodes Couchbase Servers running"
    NUM_COUCHBASE_SERVERS="0"
    while [ "$NUM_COUCHBASE_SERVERS" -ne $num_cb_nodes ]; do
	echo Retrying...
	NUM_COUCHBASE_SERVERS=$(sudo docker run tleyden5iwx/couchbase-server-$version /opt/couchbase/bin/couchbase-cli server-list -c $COUCHBASE_CLUSTER -u $CB_USERNAME -p $CB_PASSWORD | wc -l)
	sleep 5
    done
    echo "Done waiting: $numnodes Couchbase Servers are running"

    # rebalance cluster
    untilsuccessful sudo docker run tleyden5iwx/couchbase-server-$version /opt/couchbase/bin/couchbase-cli rebalance -c $COUCHBASE_CLUSTER -u $CB_USERNAME -p $CB_PASSWORD

    # create bucket
    if [ -z "$bucket" ]; then
	echo "No bucket specified, not creating one"
    else 
	echo "Create a bucket"
	untilsuccessful sudo docker run tleyden5iwx/couchbase-server-$version /opt/couchbase/bin/couchbase-cli bucket-create -c $COUCHBASE_CLUSTER -u $CB_USERNAME -p $CB_PASSWORD --bucket=$bucket --bucket-ramsize=$bucket_size
	echo "Done: created a bucket"
    fi

fi


# add values to etcd
etcdctl set /services/sync-gateway/config "$configFileOrURL"
etcdctl set /services/sync-gateway/commit "$commit"

# clone repo with fleet unit files
git clone https://github.com/tleyden/sync-gateway-coreos.git

# register fleet untit files
cd sync-gateway-coreos/fleet && fleetctl submit *.service

# generate unit files from template
for i in `seq 1 $numnodes`;
do
   fleetctl start sync_gw_node@$i.service && fleetctl start sync_gw_announce@$i.service
done
