
## Overall architecture

![architecture diagram](http://tleyden-misc.s3.amazonaws.com/blog_images/sync-gw-coreos-onion.png)


## Couchbase Server

Folow the steps in [couchbase-server-coreos](https://github.com/tleyden/couchbase-server-coreos) to get a Couchbase Server cluster up and running.

## Download cluster-init script

```
$ mkdir sync-gateway && cd sync-gateway
$ wget https://raw.githubusercontent.com/tleyden/sync-gateway-coreos/master/scripts/cluster-init.sh
$ chmod +x cluster-init.sh
```

## Launch cluster

```
$ ./cluster-init.sh -n 1 -c "master" -g "http://bit.ly/1Edo7OX"
```

You'll need to replace `http://bit.ly/1Edo7OX` with a link to your Sync Gateway config.  For example, a github gist file or a file hosted on your own webserver.

See [cluster-init.sh](https://raw.githubusercontent.com/tleyden/sync-gateway-coreos/master/scripts/cluster-init.sh) for a description of the other args.



