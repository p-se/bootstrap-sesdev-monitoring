#!/usr/bin/env bash

reboot_required=false

install_node_exporter() {
    fsid=$(ceph -s --format=json | jq -r .fsid)
    ne_name="node-exporter.ceph.com"
    for node in $(ceph orchestrator host ls --format=json | jq -r '.[].host') ; do
        ssh $node "export CEPHADM_IMAGE='prom/node-exporter:latest'; cephadm deploy \
			--name $ne_name \
        --fsid $fsid"
        ssh $node "systemctl status ceph-$fsid@$ne_name"
    done
}

install_tools() {
    for node in $(ceph orchestrator host ls --format=json | jq -r '.[].host') ; do
        ssh $node zypper ref
        # zsh
        ssh $node zypper -n in zsh
        ssh $node "cd /tmp ; \
			curl -O https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh && \
			CHSH=no RUNZSH=no sh install.sh && \
        chsh -s $(which zsh)"
        ssh $node "sed -i 's/# DISABLE_AUTO_UPDATE/DISABLE_AUTO_UPDATE/g' /root/.zshrc"
        # fzf
        ssh $node git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
        ssh $node bash ~/.fzf/install --all # --all prevents any user interaction
        # ripgrep
        ssh $node zypper -n in ripgrep ripgrep-bash-completion ripgrep-zsh-completion
        # vim
        ssh $node 'echo "ino jk <esc>\nnn H ^\nnn L $\nset ai si et sw=4 ts=4 sts=4\nsyntax enable" > /root/.vimrc'
    done
}

install_prometheus() {
	read -r -d '' prometheus_json <<-EOF
	{
		"prometheus.yml": [
			"global:",
			"  scrape_interval: 5s",
			"  evaluation_interval: 10s",
			"",
			"rule_files: ",
			"  - '/etc/prometheus/alerting/*'",
			"",
			"scrape_configs:",
			"  - job_name: 'prometheus'",
			"    static_configs:",
			"      - targets: ['localhost:9095']",
			"  - job_name: 'node-exporter'",
			"    static_configs:",
			"      - targets:",
			"         - admin:9100",
			"         - node1:9100",
			"         - node2:9100"
		]
	}
	EOF
    nodes=(admin)
    fsid=$(ceph -s --format=json | jq -r .fsid)
    tmp_config_file="/tmp/prometheus.json"
    prom_name="prometheus.admin.com"
    for node in $nodes ; do
        echo "$prometheus_json" | ssh $node -T "cat > $tmp_config_file"
        ssh $node "export CEPHADM_IMAGE='prom/prometheus:latest'; cephadm deploy \
			--name $prom_name \
			--fsid $(ceph -s --format=json | jq -r .fsid) \
        --config-json /tmp/prometheus.json"
        ssh $node "systemctl status ceph-$fsid@$prom_name"
    done
}

fix_apparmor() {
    for node in $(ceph orchestrator host ls --format=json | jq -r '.[].host') ; do
        ssh $node zypper -n in apparmor-profiles
        reboot_required=true
    done
}

fix_podman() {
    for node in $(ceph orchestrator host ls --format=json | jq -r '.[].host') ; do
        ssh $node zypper -n in podman-cni-config
        reboot_required=true
    done
}

activate_cgroup_memory() {
    for node in $(ceph orchestrator host ls --format=json | jq -r '.[].host') ; do
        cmd=$(
			base64 -w0 <<-EOF
				awk -i inplace '
					/GRUB_CMDLINE_LINUX.*cgroup_enable=memory/{print; next}
					{
						gsub(/GRUB_CMDLINE_LINUX="/, "GRUB_CMDLINE_LINUX=\42cgroup_enable=memory swapaccount=1 ")
						print
					}
				' /etc/default/grub
			EOF
        )
        ssh $node "echo $cmd | base64 -d | bash"
        reboot_required=true
    done
}

reboot_all() {
    for node in $(ceph orchestrator host ls --format=json | jq -r '.[].host') ; do
        if [[ "$node" != "admin" ]] ; then
            echo "rebooting $node"
            ssh $node reboot
        fi
    done
    echo "rebooting admin"
    ssh admin reboot
}

check_reboot_required() {
    if [[ "$reboot_required" == "true" ]] ; then
        echo "Reboot of all machines required, do you want to reboot now?"
        read a
        if [[ "$a" == "yes" || "$a" == "y" ]] ; then
            reboot_all
        fi
    fi
}

prepare_all() {
    fix_apparmor
    fix_podman
    activate_cgroup_memory
    check_reboot_required
}

deploy_all() {
    install_tools
    prepare_all
    install_prometheus
    install_node_exporter
}
