#!/usr/bin/env bash
# Copyright 2014-2017, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Shell Opts ----------------------------------------------------------------

set -e -u -x
set -o pipefail

export BASE_DIR=${BASE_DIR:-"/opt/rpc-openstack"}
source ${BASE_DIR}/scripts/functions.sh

# setup Octavia
run_ansible /opt/rpc-octavia/playbooks/main.yml

cd /opt/rpc-openstack/openstack-ansible/playbooks/

#rebuild neutron-agent container networking if deploying AIO
if [[ "${DEPLOY_AIO}" == "yes" ]]; then
  run_ansible lxc-containers-create.yml -e 'lxc_container_allow_restarts=false' --limit neutron_agents_container

fi

# build container
run_ansible lxc-containers-create.yml -e 'lxc_container_allow_restarts=false' --limit octavia_all
run_ansible os-neutron-install.yml --tags neutron-config
# install octavia
# Note: We overwrite how pip is run in os-octavia-install
run_ansible  -e @/opt/rpc-octavia/playbooks/group_vars/all/octavia.yml -e @/opt/rpc-octavia/playbooks/group_vars/octavia_all.yml -e "octavia_developer_mode=True" /opt/rpc-octavia/playbooks/os-octavia-install.yml
# add service to haproxy
run_ansible haproxy-install.yml -e @/opt/rpc-octavia/playbooks/group_vars/all/octavia.yml
# add filebeat to service so we get logging
cd /opt/rpc-openstack/
run_ansible /opt/rpc-openstack/rpcd/playbooks/filebeat.yml --limit octavia_all