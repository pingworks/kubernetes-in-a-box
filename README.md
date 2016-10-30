# Kubernetes in a Box

This repository should help you getting started with [kubernetes](https://kubernetes.io). It uses [vagrant](https://vagrantup.com) and [virtualbox](https://virtualbox.org) to spin up a vm on your machine and set up a single node kubernetes cluster.

It is as easy as:

    git clone https://github.com/pingworks/kubernetes-in-a-box
    cd kubernetes-in-a-box
    vagrant up

Just grab a coffee and wait till the provisioning has finished.

It will setup a kubernetes cluster running a private docker registry and the kubernetes dashboard ui.

## Accessing the cluster services
The vm will use one host only network interface with IP 192.168.200.2. This IP is accessible from your host system. All services in the kubernetes cluster will get IPs from the network 100.64.0.0/12. To make those IPs accessible directly from your host you have to add a route. On linux this can be done by running:

    sudo ip r a 100.64.0.0/12 via 192.168.200.2

## Using the cluster's DNS server
The kubernetes cluster uses the domain cluster.local for all services. For every new service kubernetes create a DNS entry automatically. This DNS names will look like: <service-name>.<namespace>.svc.cluster.local. If you want to use these DNS names from your host system you have to use the cluster's nameserver (100.64.0.10) for nameresolution. On linux this can be done by:

    echo "nameserver 100.64.0.10" | sudo resolvconf -a wlan"

## Available cluster services
* API server

 The API server is listening on
[https://kubernetes.default.svc.cluster.local/](https://kubernetes.default.svc.cluster.local/) or
[https://100.64.0.1/](https://100.64.0.1/)

* Dashboard

 The Dashboard can be found on [https://kubernetes.default.svc.cluster.local/ui](https://kubernetes.default.svc.cluster.local/ui) or [https://100.64.0.1/ui](https://100.64.0.1/ui)

* Private Docker Registry

 The cluster is running a private docker registry. This can be found on: kube-registry.kube-system.svc.cluster.local:5000
