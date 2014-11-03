
## Overall architecture

![architecture diagram](http://tleyden-misc.s3.amazonaws.com/blog_images/sync-gw-coreos-onion.png)

Since this repo *only* contains things related to [Sync Gateway](https://github.com/couchbase/sync_gateway), if you want the entire system you'll also need to check out [couchbase-server-coreos](https://github.com/tleyden/couchbase-server-coreos).

## Repo contents

* A Dockerfile to build a Sync Gateway docker container
* Fleet unit file(s) to launch Sync Gateway 

## Sync Gateway version

Rather than pinning the Docker image to a particular Sync Gateway version, this takes advantage of the fact that Sync Gateway compiles in mere seconds.  

* If you don't pass in anything for the version, it will use the master branch at the time the image was built.
* If you pass in a branch name, it will use the latest commit on that branch at the time of container launch.  (it will first pull that and rebuild)
* If you pass in a commit hash, it will do the same, but for that commit.

