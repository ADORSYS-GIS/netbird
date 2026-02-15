---
all:
  children:
%{ if length(netbird_primary) > 0 ~}
    netbird_servers:
      hosts:
%{ for vm in netbird_primary ~}
        ${vm.name}:
          ansible_host: ${vm.public_ip != "" ? vm.public_ip : vm.private_ip}
          ansible_user: ${vm.ssh_user}
          private_ip: ${vm.private_ip}
          cloud_provider: ${vm.cloud}
          cloud_region: ${vm.region}
          instance_id: ${vm.instance_id}
%{ endfor ~}
%{ endif ~}

%{ if length(relay_servers) > 0 ~}
    netbird_relay_servers:
      hosts:
%{ for vm in relay_servers ~}
        ${vm.name}:
          ansible_host: ${vm.public_ip != "" ? vm.public_ip : vm.private_ip}
          ansible_user: ${vm.ssh_user}
          private_ip: ${vm.private_ip}
          cloud_provider: ${vm.cloud}
          cloud_region: ${vm.region}
          instance_id: ${vm.instance_id}
%{ endfor ~}
%{ endif ~}
