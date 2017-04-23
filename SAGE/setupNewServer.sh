#!/bin/bash
# Installs Docker on a DM Challenge machine.
#
# - requires the machine to be listed in .ssh/config
# - requires the user "dreamuser" to be created on the machine
#   with specific SSH public key added to its .ssh/authorized_keys
# - requires the user "dreamuser" to be added to sudoers without
#   password requirement
#
# The script will not be successfully if run a second time on a
# machine that has been configured to use a Logical Volume for
# docker's data thinpool. Docker must first be stopped on the machine,
# its configuration must be edit to remove reference to the LV, and
# /var/lib/docker/* must be removed.
#
# Examples:
# ./setupNewServer.sh softlayer bm13
# ./setupNewServer.sh amazon am01 <Elastic IP>
#
# Author: Bruce Hoff
# Author: Thomas Schaffter (thomas.schaff...@gmail.com)
# Last update: 2016-11-10

function errorExit() {
    echo "ERROR: $1" >&2
    exit 1
}

trap errorExit INT

# softlayer or amazon
[ "$#" -ge 1 ] || errorExit "Cloud type missing (softlayer or amazon)"
([ $1 == "softlayer" ] || [ $1 == "amazon" ]) || errorExit "Unknown cloud type (softlayer or amazon)"
cloud=$1

# name of the machine
[ "$#" -ge 2 ] || errorExit "Machine name missing"
name=$2

# address of the machine
if [ "$#" -ge 3 ]; then
	address=$3
elif [ $cloud == "softlayer" ]; then
	address=${name}-dreamchallenge.sl851865.sl.edst.ibm.com
else
	errorExit "Machine address missing"
fi

# Install and configure Docker on the target machine
rm -rf /home/ubuntu/.docker/machine/machines/${name}
docker-machine create --driver generic --generic-ip-address=${address} --generic-ssh-key=/home/ubuntu/.ssh/id_rsa_docker-machine --generic-ssh-user=dreamuser ${name} || errorExit "docker-machine create failed."

ssh ${name} sudo chmod 777 /etc/docker
scp ~/.docker/machine/certs/key.pem ${name}:/etc/docker/.
scp ~/.docker/machine/certs/cert.pem ${name}:/etc/docker/.
ssh ${name} sudo chmod 666 /etc/resolv.conf

if [ $cloud == "softlayer" ]; then
	echo "Fixing /etc/resolv.conf (SoftLayer only)"
	ssh ${name} sudo "printf \"nameserver 10.0.80.11\nnameserver 10.0.80.12\noptions single-request\n\" > /etc/resolv.conf"
	ssh ${name} sudo "service network restart"
fi
ssh ${name} sudo sysctl -w net.ipv4.ip_forward=1
sleep 60

# Configure Docker to use a Logical Volume for its thinpool
# https://github.com/Sage-Bionetworks/DigitalMammographyChallenge/issues/3#issuecomment-256758426
: <<'END'
if [ $cloud == "softlayer" ]; then
	echo "Configuring Docker to use a Logical Volume for its data thinpool"
	ssh ${name} sudo service docker stop
	
	ssh ${name} sudo lvremove --yes /dev/mapper/data-thinpool
	ssh ${name} sudo lvcreate --yes --wipesignatures y --name thinpool --size 500G data
	ssh ${name} sudo lvcreate --yes --wipesignatures y --name thinpoolmeta --size 4G data
	ssh ${name} sudo lvconvert --yes --zero n -c 512K --thinpool data/thinpool --poolmetadata data/thinpoolmeta
	ssh ${name} sudo rm -fr /var/lib/docker/
	ssh ${name} sudo mkdir /var/lib/docker
	ssh ${name} sudo chmod 711 /var/lib/docker

	ORIGINAL="--storage-driver devicemapper"
	EXTRA="--storage-opt=dm.thinpooldev=/dev/mapper/data-thinpool --storage-opt=dm.use_deferred_removal=true --storage-opt=dm.use_deferred_deletion=true"
	ssh ${name} sudo "sed -i 's:$EXTRA ::' /etc/systemd/system/docker.service"
	ssh ${name} sudo "sed -i 's:$ORIGINAL:$ORIGINAL $EXTRA:' /etc/systemd/system/docker.service"
	ssh ${name} sudo systemctl daemon-reload
	ssh ${name} sudo service docker restart || errorExit "Unable to configure docker to use a LV for its data thinpool."
fi
END

# Set the size of docker data space
echo "Configuring Docker data space"
ssh ${name} sudo service docker stop
ssh ${name} sudo rm -fr /var/lib/docker/
ssh ${name} sudo mkdir /var/lib/docker
ssh ${name} sudo chmod 711 /var/lib/docker
DOCKER_STORAGE_CONFIGURATION_DEFAULT="--storage-driver devicemapper"
DOCKER_STORAGE_CONFIGURATION_NEW="--storage-driver devicemapper --storage-opt dm.loopdatasize=75G"
ssh ${name} sudo "sed -i 's:$DOCKER_STORAGE_CONFIGURATION_DEFAULT:$DOCKER_STORAGE_CONFIGURATION_NEW:' /etc/systemd/system/docker.service"
ssh ${name} sudo systemctl daemon-reload
ssh ${name} sudo service docker start || errorExit "Unable to configure docker data space"

# Install nvidia-docker
ssh ${name} sudo wget -P /tmp https://github.com/NVIDIA/nvidia-docker/releases/download/v1.0.0/nvidia-docker-1.0.0-1.x86_64.rpm || errorExit "Unable to download nvidia-docker"
ssh ${name} sudo rpm -i /tmp/nvidia-docker*.rpm && ssh ${name} rm /tmp/nvidia-docker*.rpm
ssh ${name} sudo systemctl start nvidia-docker

# Update the configuration of nvidia-docker
echo "Updating nvidia-docker configuration"
ssh ${name} sudo service nvidia-docker stop
ssh ${name} sudo "sed '/ExecStart=/s/ -l :3476//g' -i /usr/lib/systemd/system/nvidia-docker.service"
ssh ${name} sudo "sed '/ExecStart=/s/$/ -l :3476/' -i /usr/lib/systemd/system/nvidia-docker.service"
ssh ${name} sudo systemctl daemon-reload
ssh ${name} sudo service nvidia-docker restart || errorExit "Unable to update nvidia-docker configuration."

# Make sure docker and nvidia-docker run at startup
ssh ${name} sudo chkconfig docker on
ssh ${name} sudo chkconfig nvidia-docker on

# Set docker-machine to use this machine
eval $(docker-machine env ${name})
if [[ $(docker-machine active) != ${name} ]]; then
	echo host is ${name} but active Docker Engine is $(docker-machine active)
	exit 1
fi

echo "Exiting before installing sysdig and nvml-statsd."
exit $?


# Run Sysdig agent
docker run -d --name sysdig-agent --privileged --net host --pid host -e ACCESS_KEY=${SYSDIG_AGENT_ACCESS_KEY} -e TAGS=$SYSDIG_TAGS -v /var/run/docker.sock:/host/var/run/docker.sock -v /dev:/host/dev -v /proc:/host/proc:ro -v /boot:/host/boot:ro -v /lib/modules:/host/lib/modules:ro -v /usr:/host/usr:ro --restart unless-stopped --cpuset-cpus "0" --memory 512m --memory-swap 0m sysdig/agent
docker exec sysdig-agent bash -c "echo collector_port: 80 >> /opt/draios/etc/dragent.yaml"
docker restart sysdig-agent

# Run nvml-statsd
docker login docker.synapse.org -u ${SYNAPSE_USERNAME} -p ${SYNAPSE_PASSWORD}
docker login -u ${DOCKERHUB_USERNAME} -p ${DOCKERHUB_PASSWORD}

NVIDIA_OPTIONS=$(ssh ${name} curl -s localhost:3476/v1.0/docker/cli)
# Filtering to keep only the --device
NVIDIA_OPTIONS=($NVIDIA_OPTIONS)
NVIDIA_DEVICES=()
for item in "${NVIDIA_OPTIONS[@]}"
do
	if [[ "$item" =~ "--device" ]]; then
		NVIDIA_DEVICES[${#NVIDIA_DEVICES[@]}]="${item}"
	fi
done
NVIDIA_DEVICES=$(printf " %s" "${NVIDIA_DEVICES[@]}")
echo "NVIDIA devices: $NVIDIA_DEVICES"

docker run -d \
-e statsd_host=localhost \
$NVIDIA_DEVICES \
-v /usr/lib64/nvidia/libnvidia-ml.so.1:/usr/lib64/libnvidia-ml.so.1:ro \
-v /usr/lib64/nvidia/libnvidia-ml.so.367.48:/usr/lib64/libnvidia-ml.so.367.48:ro \
--restart unless-stopped \
--cpuset-cpus "0" \
--memory 512m \
--memory-swap 0m \
--name nvml-statsd \
docker.synapse.org/syn5644795/nvml-statsd

# The container nvml-statd doesn't start at boot time if
# the NVIDIA devices are not mounted at that time.
# A solution is to add the following command to crontab.
ssh ${name} 'sudo crontab -l > /tmp/mycron'
ssh ${name} sudo sed -i "/nvml-statsd/d" /tmp/mycron
ssh ${name} 'sudo echo "@reboot sleep 300; /usr/bin/docker start nvml-statsd" >> /tmp/mycron'
ssh ${name} sudo crontab /tmp/mycron && ssh ${name} rm /tmp/mycron

echo "Done"
