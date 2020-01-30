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

install_grafana() {
    read -r -d '' grafana_json <<-EOF
{
    "grafana.ini": [
            "[users]",
            "  default_theme = light",
            "[auth.anonymous]",
            "  enabled = true",
            "  org_name = 'Main Org.'",
            "  org_role = 'Viewer'",
            "[server]",
            "  domain = 'bootstrap.storage.lab'",
            "  protocol = https",
            "  cert_file = /etc/grafana/certs/cert_file",
            "  cert_key = /etc/grafana/certs/cert_key",
            "  http_port = 3000",
            "  http_addr = localhost",
            "[security]",
            "  admin_user = admin",
            "  admin_password = admin",
            "  allow_embedding = true"
    ],
    "provisioning/datasources/ceph-dashboard.yml": [
            "deleteDatasources:",
            "  - name: 'Dashboard'",
            "    orgId: 1",
            " ",
            "datasources:",
            "  - name: 'Dashboard'",
            "    type: 'prometheus'",
            "    access: 'proxy'",
            "    orgId: 1",
            "    url: 'http://localhost:9095'",
            "    basicAuth: false",
            "    isDefault: true",
            "    editable: false"
    ],
    "certs/cert_file": [
        "-----BEGIN CERTIFICATE-----",
        "MIIDLTCCAhWgAwIBAgIUEH0mq6u93LKsWlNXst5pxWcuqkQwDQYJKoZIhvcNAQEL",
        "BQAwJjELMAkGA1UECgwCSVQxFzAVBgNVBAMMDmNlcGgtZGFzaGJvYXJkMB4XDTIw",
        "MDEwNTIyNDYyMFoXDTMwMDEwMjIyNDYyMFowJjELMAkGA1UECgwCSVQxFzAVBgNV",
        "BAMMDmNlcGgtZGFzaGJvYXJkMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKC",
        "AQEAqxh6eO0NTZJe+DoKZG/kozJCf+83eB3gWzwXoNinRmV/49f5WPR20DIxAe0R",
        "saO6XynJXTrhvXT1bsARUq+LSmjWNFoYXopFuOJhGdWn4dmpuHwtpcFv2kjzNOKj",
        "U2EG8j6bsRp1jFAzn7kdbSWT0UHySRXp9DPAjDiF3LjykMXiJMReccFXrB1pRi93",
        "nJxED8d6oT5GazGB44svb+Zi6ABamZu5SDJC1Fr/O5rWFNQkH4hQEqDPj1817H9O",
        "sm0mZiNy77ZQuAzOgZN153L3QOsyJismwNHfAMGMH9mzPKOjyhc13VlZyeEzml8p",
        "ZpWQ2gi8P2r/FAr8bFL3MFnHKwIDAQABo1MwUTAdBgNVHQ4EFgQUZg3v7MX4J+hx",
        "w3HENCrUkMK8tbwwHwYDVR0jBBgwFoAUZg3v7MX4J+hxw3HENCrUkMK8tbwwDwYD",
        "VR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAaR/XPGKwUgVwH3KXAb6+",
        "s9NTAt6lCmFdQz1ngoqFSizW7KGSXnOgd6xTiUCR0Tjjo2zKCwhIINaI6mwqMbrg",
        "BOjb7diaqwFaitRs27AtdmaqMGndUqEBUn/k64Ld3VPGL4p0W2W+tXsyzZg1qQIn",
        "JXb7c4+oWzXny7gHFheYQTwnHzDcNOf9vJiMGyYYvU1xTOGucu6dwtOVDDe1Z4Nq",
        "AyIYWDScRr2FeAOXyx4aW2v5bjpTxvP+79/OOBbQ+p4y5F4PDrPeOSweGoo6huTR",
        "+T+YI9Jfw2XCgV7NHWhfdt3fHHwUQzO6WszWU557pmCODLvXWsQ8P+GRiG7Nywm3",
        "uA==",
        "-----END CERTIFICATE-----"
    ],
    "certs/cert_key": [
        "-----BEGIN PRIVATE KEY-----",
        "MIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCrGHp47Q1Nkl74",
        "Ogpkb+SjMkJ/7zd4HeBbPBeg2KdGZX/j1/lY9HbQMjEB7RGxo7pfKcldOuG9dPVu",
        "wBFSr4tKaNY0WhheikW44mEZ1afh2am4fC2lwW/aSPM04qNTYQbyPpuxGnWMUDOf",
        "uR1tJZPRQfJJFen0M8CMOIXcuPKQxeIkxF5xwVesHWlGL3ecnEQPx3qhPkZrMYHj",
        "iy9v5mLoAFqZm7lIMkLUWv87mtYU1CQfiFASoM+PXzXsf06ybSZmI3LvtlC4DM6B",
        "k3XncvdA6zImKybA0d8AwYwf2bM8o6PKFzXdWVnJ4TOaXylmlZDaCLw/av8UCvxs",
        "UvcwWccrAgMBAAECggEAeBv0BiYrm5QwdUORfhaKxAIJavRM1Vbr5EBYOgM90o54",
        "bEN2ePsM2XUSsE5ziGfu8tVL1dX7GNwdW8UbpBc1ymO0VAYXa27YKUVKcy9o7oS1",
        "v5v1E5Kq6esiSLL9gw/vJ2nKNFblxD2dL/hs7u1dSp5n7uSiW1tlRUp8toljRzts",
        "1Cenp0J/a82HwWDE8j/H9NvitTOZ2cdwJ76V8GkBynlvr2ARjRfZGx0WXEJmoZYD",
        "YUQVU303DB6Q2tkFco4LbPofkuhhMPhXsz3fZ/blHj/c78tqP9L5sQ29oqoPE1pS",
        "DBOwKC/eoi5FY34RdLNL0dKq9MzbuYqEcCfZOJgxoQKBgQDf+5XF+aXQz2OmSaj6",
        "1Yr+3KAKdfX/AYp22X1Wy4zWcZlgujgwQ1FG0zay8HVBM0/xn4UgOtcKCoXibePh",
        "ag1t8aZINdRE1JcMzKmZoSvU9Xk30CNvygizuJVEKsJFPDbPzCpauDSplzcQb4pZ",
        "wepucPuowkPMBx0iU3x0qSThWwKBgQDDjYs7d30xxSqWWXyCOZshy7UtHMNfqP15",
        "kDfTXIZzuHvDf6ZNci10VY1eDZbpZfHgc6x1ElbKv2H4dYsgkENJZUi1YQDpVPKq",
        "4N5teNykgAuagiR7dRFltSju3S7hIE6HInTv3hShaFPymlEE7zuBMuEUcuvYz5YN",
        "RjxsvypKcQKBgCuuV+Y1KqZPW8K5SNAqRyIvCrMfkCr8NPG6tpvvtHa5zsyzZHPd",
        "HQOv+1HoXSWrCSM5FfBUKU3XAYdIIRH76cSQRPp+LPiDcTXY0Baa/P5aJRrCZ7bM",
        "cugBznJt2FdCR/o8eeIZXIPabq2w4w1gKQUC2cFuqWQn2wGvwGzL89pTAoGAAfpx",
        "mSVpT9KVzrWTC+I3To04BP/QfixAfDVYSzwZZBxOrDijXw8zpISlDHmIuE2+t62T",
        "5g9Mb3qmLBRMVwT+mUR8CtGzZ6jjV5U0yti5KrTc6TA93D3f8i51/oygR8jC4p0X",
        "n8GYZdWfW8nx3eHpsTHpkwJinmvjMbkvLU51yBECgYAnUAMyhNOWjbYS5QWd8i1W",
        "SFQansVDeeT98RebrzmGwlgrCImHItJz0Tz8gkNB3+S2B2balqT0WHaDxQ8vCtwX",
        "xB4wd+gMomgdYtHGRnRwj1UyRXDk0c1TgGdRjOn3URaezBMibHTQSbFgPciJgAuU",
        "mEl75h1ToBX9yvnH39o50g==",
        "-----END PRIVATE KEY-----"
    ]
}
EOF
    echo "$grafana_json" > /tmp/grafana.json
    CEPHADM_IMAGE='pcuzner/ceph-grafana-el8:latest' cephadm deploy \
      --name grafana.admin.com \
      --fsid $(ceph fsid) \
      --config-json /tmp/grafana.json
}

install_tools() {
    for node in $(ceph orchestrator host ls --format=json | jq -r '.[].host') ; do
        ssh $node zypper ref
        # zsh
        ssh $node zypper -n in zsh vim-data
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
        ssh $node 'echo "ino jk <esc>\nnn H ^\nnn L $\nset ai si et sw=4 ts=4 sts=4 hlsearch\nsyntax enable" > /root/.vimrc'
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
