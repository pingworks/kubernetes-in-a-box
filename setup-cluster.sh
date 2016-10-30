#!/bin/bash

set -e

USERNAME=${SUDO_USER}
NAMESPACE=$USERNAME

function log_start {
  echo "####################################"
  echo "# $1"
  echo "####################################"
}

function log_end {
  echo "####################################"
  echo "# done."
  echo "####################################"
  echo "#"
}

dpkg -l kubelet >/dev/null 2>&1 || (
  log_start "Installing kubernetes.."
  [ -d /etc/apt/sources.list.d/kubernetes.list ] \
    || cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
  apt-key list | grep '2048R/A7317B0F' >/dev/null \
    || curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  apt-get update && apt-get install -y docker.io kubelet kubeadm kubectl kubernetes-cni
  log_end
)

id $USERNAME | grep docker > /dev/null || (
  log_start "Adding user to docker group.."
  adduser $USERNAME docker
  log_end
)

[ -d /etc/kubernetes/pki ] || (
  log_start "Initializing Cluster.."
  kubeadm init \
    --api-advertise-addresses 192.168.200.2 \
    --use-kubernetes-version v1.4.5 \
    | tee /vagrant/kubeinit.out && sleep 2
  grep '^kubeadm join --token' /vagrant/kubeinit.out > /vagrant/kubeadm-join
  kubectl taint nodes --all dedicated-
  log_end
)

[ -e /etc/kubernetes/pki/basic-auth.csv ] \
  || echo 'admin,admin,1000' > /etc/kubernetes/pki/basic-auth.csv
grep 'basic-auth-file' /etc/kubernetes/manifests/kube-apiserver.json >/dev/null || (
  log_start "Configuring basic-auth for api server.."
  oldpid=$(pidof kube-apiserver)
  sed -i -e 's;"--token-auth-file=/etc/kubernetes/pki/tokens.csv",;"--token-auth-file=/etc/kubernetes/pki/tokens.csv",\n          "--basic-auth-file=/etc/kubernetes/pki/basic-auth.csv",;' /etc/kubernetes/manifests/kube-apiserver.json
  kill -HUP $oldpid
  echo -n "Waiting for kube-apiserver to restart"
  while [ "$(pidof kube-apiserver)" = "$oldpid" ]; do
    echo -n "."
    sleep 1
  done
  echo "waiting 20s seconds for api server to be available again."
  sleep 20
  echo
  log_end
)

kubectl describe daemonset weave-net --namespace=kube-system > /dev/null 2>&1 || (
  log_start "Deploying pod network.."
  kubectl apply -f https://git.io/weave-kube
  log_end
)

kubectl describe deployment kubernetes-dashboard --namespace=kube-system >/dev/null 2>&1 || (
  log_start "Deploying dashboard.."
  kubectl apply -f https://rawgit.com/kubernetes/dashboard/master/src/deploy/kubernetes-dashboard.yaml
  log_end
)

log_start "Waiting for cluster pods to become ready.."
output=$(kubectl get pods --all-namespaces)
echo "$output"
while echo "$output" | awk '{print $4}' | grep -v STATUS | grep -v Running >/dev/null; do
  echo '------------------- Waiting 3 sec. -------------------'
  sleep 3
  output=$(kubectl get pods --all-namespaces)
  echo "$output"
done
echo
echo "Pods ready, waiting another 10s"
sleep 10
log_end

[ -d ~/.kube ] && sudo chown -R $USERNAME:$USERNAME ~/.kube

kubectl describe rc kube-registry --namespace=kube-system >/dev/null 2>&1 || (
  log_start "Setting up kubernetes registry.."
  [ -e /vagrant/registry/registry.key ] || (
    openssl req -x509 -config /vagrant/registry/openssl.conf \
      -nodes -newkey rsa:2048 \
      -keyout /vagrant/registry/registry.key \
      -out /vagrant/registry/registry.crt > /dev/null 2>&1
  )
  kubectl --namespace=kube-system describe secret registry-tls-secret > /dev/null 2>&1 || (
    kubectl --namespace=kube-system create secret generic registry-tls-secret \
      --from-file=/vagrant/registry/registry.crt \
      --from-file=/vagrant/registry/registry.key
  )
  mkdir -p /data/kube-registry
  kubectl apply -f /vagrant/registry/deployment-registry.yaml
  kubectl apply -f /vagrant/registry/service-registry.yaml
  mkdir -p /etc/docker/certs.d/kube-registry.kube-system.svc.cluster.local\:5000
  cp /vagrant/registry/registry.crt /etc/docker/certs.d/kube-registry.kube-system.svc.cluster.local\:5000/ca.crt
  log_end
)

log_start "Configuring name resolution.."
IFACE=enp0s3
sed -i -e "s;iface $IFACE inet dhcp;iface $IFACE inet dhcp\ndns-nameserver 100.64.0.10;" /etc/network/interfaces
ifdown $IFACE > /dev/null 2>&1
ifup $IFACE > /dev/null 2>&1
log_end

echo "##############################################################################"
echo "# Your local cluster is set up."
echo "#"
echo "# To access the service ip net (100.64.0.0/12) add a route on your host:"
echo "# linux: sudo ip r a 100.64.0.0/12 via 192.168.200.2"
echo "# mac:   sudo route -n add -net 100.64.0.0/12 192.168.200.2"
echo "#"
echo "# To resolv DNS names from the cluster add 100.64.0.10 as DNS."
echo "# linux: echo \"nameserver 100.64.0.10\" | sudo resolvconf -a wlan"
echo "# mac:   sudo networksetup -setdnsservers Wi-Fi 100.64.0.10"
echo "#"
echo "# To push images to the k8s registry run the following cmds on your host:"
echo "# sudo mkdir -p /etc/docker/certs.d/kube-registry.kube-system.svc.cluster.local\:5000"
echo "# sudo cp registry/registry.crt /etc/docker/certs.d/kube-registry.kube-system.svc.cluster.local\:5000/ca.crt"
echo "#"
echo "# You can access the kubernetes dashboard at: "
echo "# https://kubernetes.default.svc.cluster.local/ui or"
echo "# https://100.64.0.10/ui"
echo "##############################################################################"
echo
