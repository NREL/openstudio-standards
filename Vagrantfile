# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.require_version ">= 1.5.0"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  is_windows = (RUBY_PLATFORM =~ /mswin|mingw|cygwin/)
  use_nfs = !is_windows

  config.vm.hostname = "openstudio-standards"
  config.omnibus.chef_version = :latest

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "opscode-ubuntu-12.04"
  config.vm.box_url = "https://opscode-vm-bento.s3.amazonaws.com/vagrant/opscode_ubuntu-12.04_provisionerless.box"

  config.vm.network :private_network, ip: "192.168.31.100"
  config.vm.synced_folder ".", "/data", :nfs => use_nfs

  config.vm.provider :virtualbox do |p|
    nc = 1
    p.customize ["modifyvm", :id, "--memory", nc*2048, "--cpus", nc]
  end

  config.berkshelf.enabled = true
  config.vm.provision :chef_solo do |chef|
    chef.json = {
        :openstudio => {
            :version => "1.4.0",
            :installer => {
                :version_revision => "6b1721084f",
                :platform => "Linux-Ruby2.0"
            }
        }
    }
    chef.run_list = [
        "recipe[openstudio::default]",
        "recipe[zip::default]"
    ]
  end
end


