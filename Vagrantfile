# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.define "master", primary: true do |master|
    master.vm.hostname = "master"
    master.vm.network "private_network", ip: "192.168.200.2"
    master.vm.provider "virtualbox" do |v|
      v.name = "kube-master"
    end
    master.vm.provision "shell", path: "setup-cluster.sh", args: "#{ENV['UBUNTU_LTS']}"
  end
  
  config.ssh.forward_agent = true
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", "2048"]
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
  end
end
