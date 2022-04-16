# WorkEnv

This project deployes my current working environment.

* Currently installed tools
	* apt
		* `build-essential curl file git zsh xclip bison golang ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip doxygen fzf apt-transport-https ca-certificates gnupg-agent software-properties-common python3-pip jq`
	* oh-my-zsh
	* tpm
	* gvm
	* nvim
	* kubectl
	* nvm
	* tfenv
	* gh
	* kustomize
	* kubebuilder
	* linode-cli
	* kind
	* systemd service for tmux session
	* /dev/sdb mounted
* Loadbalancer
	* for ssh session connection
* Kubernetes cluster
	* single templated manifest
	* multi yaml document templated manifest
	* directory of templated manifests

## TODO
* Add firewall to linode to only allow ssh access from Loadbalancer.
	* Need to figure out why im hitting this bug `kex_exchange_identification: Connection closed by remote host`
* Add the usage of https://registry.terraform.io/providers/kbst/kustomization/latest/docs 
  this would allow for kustomize to be run on the templated manifests.
