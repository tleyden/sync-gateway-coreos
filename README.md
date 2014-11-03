
## Overall architecture

![architecture diagram](http://tleyden-misc.s3.amazonaws.com/blog_images/sync-gw-coreos-onion.png)


## Couchbase Server

Folow the steps in [couchbase-server-coreos](https://github.com/tleyden/couchbase-server-coreos/tree/master/2.2) to get a Couchbase Server 2.2 cluster up and running.

## Add security groups

A few ports will need to be opened up for Sync Gateway.  Edit the Couchbase-CoreOS-CoreOSSecurityGroup-xxxx security group and add the following rules: 

Type  | Protocol | Port Range | Source | 
------------- | ------------- | ------------- | ------------- 
Custom TCP Rule  | TCP | 4985 | Custom IP: sg-6e5a0d04 (copy and paste from port 4001 rule)
Custom TCP Rule  | TCP | 4984 | Anywhere: 0.0.0.0/0 


## Download cluster-init script

Ssh into one of your CoreOS instances and run:

```
$ mkdir sync-gateway && cd sync-gateway
$ wget https://raw.githubusercontent.com/tleyden/sync-gateway-coreos/master/scripts/cluster-init.sh
$ chmod +x cluster-init.sh
```

## Launch Sync Gateway server(s)

```
$ ./cluster-init.sh -n 1 -c "master" -g "http://bit.ly/1Edo7OX"
```

You'll need to replace `http://bit.ly/1Edo7OX` with a link to your own Sync Gateway config.  For example, a github gist file or a file hosted on your own webserver.  

You'll want to customize your Sync Gateway config to use Couchbase Server instead of walrus, so your config should look something like the [TodoLite config](https://github.com/couchbase/sync_gateway/blob/master/examples/democlusterconfig.json#L136-L182), with the `server` field pointing to your own Couchbase Server ip.  To find your own server IP to use, run:

```
$ echo $(etcdctl get /services/couchbase/bootstrap_ip):8091
ip-10-150-70-83.ec2.internal:8091
```

See [cluster-init.sh](https://raw.githubusercontent.com/tleyden/sync-gateway-coreos/master/scripts/cluster-init.sh) for a description of the other arguments required to this script.

## Verify internal

**Find internal ip**

```
$ fleetctl list-units
sync_gw_node.1.service				209a8a2e.../10.164.175.9	active	running
```

**Curl**

On the CoreOS instance you are already ssh'd into, Use the ip found above and run a curl request against the server root:

```
$ curl 10.164.175.9:4985
{"couchdb":"Welcome","vendor":{"name":"Couchbase Sync Gateway","version":1},"version":"Couchbase Sync Gateway/master(6356065)"}
```

## Verify external

**Find external ip**

Using the internal ip found above, go to the EC2 Instances section of the AWS console, and hunt around until you find the instance with that internal ip, and then get the public ip for that instance, eg: `ec2-54-211-206-18.compute-1.amazonaws.com`


**Curl**

From your laptop, use the ip found above and run a curl request against the server root:

```
$ curl ec2-54-211-206-18.compute-1.amazonaws.com:4984
{"couchdb":"Welcome","vendor":{"name":"Couchbase Sync Gateway","version":1},"version":"Couchbase Sync Gateway/master(6356065)"}
```

## References

* [sync gateway](https://github.com/couchbase/sync_gateway)
* [couchbase-server-coreos](https://github.com/tleyden/couchbase-server-coreos)
