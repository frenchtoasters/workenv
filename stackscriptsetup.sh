#!/bin/bash
# <UDF name="hostname" label="Hostname for system" default="lintoast">
# <UDF name="go_version" label="Go version to install" default="go1.18"/>
# <UDF name="nvim_version" label="NVIM version" default="v0.6.1"/>
# <UDF name="nvm_version" label="NVM version, for npm" default="v0.39.1"/>
# <UDF name="session_name" label="Name of the session" default="lintoast-remote"/>
# <UDF name="gh_version" label="gh version for gh-cli" default="2.6.0"/>
hostnamectl set-hostname ${hostname}

mkdir -p ~/.config
mkdir -p ~/kube/
mkdir -p ~/kube/kubeconfig

sudo apt-get update
sudo apt-get install -y build-essential curl file git zsh xclip bison golang ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip doxygen fzf apt-transport-https ca-certificates gnupg-agent software-properties-common python3-pip jq

# Zsh
if [[ "$SHELL" != "/usr/bin/zsh" ]]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  sudo chsh -s $(which zsh)
fi

# Tmux
if [[ ! -d "~/.tmux/plugins/tpm" ]]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# Go
if [[ ! -d "~/.gvm" ]]; then
  bash < <(curl -s -S -L https://raw.githubusercontent.com/moovweb/gvm/master/binscripts/gvm-installer)
  export GVM_ROOT=/root/.gvm
  source $GVM_ROOT/scripts/gvm-default
  gvm install ${go_version}
  gvm use ${go_version} --default
fi

# Neovim
if [[ ! -f  "/build/bin/nvim" ]]; then
  git clone https://github.com/neovim/neovim
  cd neovim && git checkout ${nvim_version} && make && make install
  mv /build/bin/nvim /usr/bin/nvim
  cd ~
fi

if [[ ! -d "~/.config/nvim" ]]; then
  git clone https://github.com/frenchtoasters/dotfiles.git
  cd ~
  mv ~/dotfiles ~/.config/nvim
  cp ~/.config/nvim/.zshrc-copy ~/.zshrc
  cp ~/.config/nvim/.tmux.conf ~/.tmux.conf
fi

# kubectl
if [[ ! -f "/usr/local/bin/kubectl" ]]; then
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# npm
if [[  ! -d "~/.nvm" ]]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_version}/install.sh | bash
  source ~/.zshrc
  nvm install --lts
  nvm use --lts
fi 

# tfenv
if [[ ! -d "~/.tfenv" ]]; then
  git clone https://github.com/tfutils/tfenv.git ~/.tfenv
  source ~/.zshrc
  tfenv init
  tfenv install latest
  tfenv use latest
fi

# github
if [[ ! -f "/usr/local/bin/gh" ]]; then
  curl -LO https://github.com/cli/cli/releases/download/v${gh_version}/gh_${gh_version}_linux_amd64.tar.gz
  tar -zxvf gh_${gh_version}_linux_amd64.tar.gz
  chmod +x ~/gh_${gh_version}_linux_amd64/bin/gh
  mv ~/gh_${gh_version}_linux_amd64/bin/gh /usr/local/bin/gh
fi

# kustomize
if [[ ! -f "/usr/local/bin/kustomize" ]]; then
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
  mv ~/kustomize /usr/local/bin/kustomize
fi

# kube-builder
if [[ ! -f "/usr/local/bin/kubebuilder" ]]; then
  curl -L -o kubebuilder https://go.kubebuilder.io/dl/latest/linux/amd64
  chmod +x kubebuilder && mv kubebuilder /usr/local/bin/
fi

# linode-cli
if [[ ! -f "/usr/local/bin/linode-cli" ]]; then
  python3 -m pip install linode-cli
fi

# kind
if [[ ! -f "/usr/local/bin/kind" ]]; then
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.12.0/kind-linux-amd64
  chmod +x ./kind
  mv ./kind /usr/local/bin/kind
fi

# Create session service
if [[ ! -f "/etc/systemd/system/${session_name}.service" ]]; then
	echo "[Unit]
		Description=tmux ${session_name} service

		[Service]
		Type=forking
		User=root
		ExecStart=/usr/bin/tmux new-session -d -s ${session_name}-remote
		ExecStop=/usr/bin/tmux kill-session -t ${session_name}-remote

		[Install]
		WantedBy=multi-user.target" > ${session_name}.service
	mv ./${session_name}.service /etc/systemd/system/
	systemctl daemon-reload
	systemctl enable ${session_name}.service
	systemctl start ${session_name}.service
fi

mkdir -p /keep
echo "/dev/sdb /keep ext4 defaults 0 2" >> /etc/fstab

if mount -a; then
	touch /keep/existed
	echo "EXISTED" > /keep/existed
else
	mkfs.ext4 /dev/sdb
	mount /dev/sdb /keep
	cp -r ~/.config/nvim/* /keep
fi

