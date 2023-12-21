#! /bin/bash

if [ -n "$shared_dir" ]; then
    echo "Using shared drive: $shared_dir"
    jq ". += {"setup_nfs": false}" config.json > temp.json && mv temp.json config.json
else
    PUBLIC_NFS_SERVER_IP=$(jq -r '.HEADNODE_IP | .[0]' config.json)
    USERNAME=$admin_name

    shared_dir="/home/$USERNAME/neuraldb_enterprise/model_bazaar"
    echo "Mounting shared drive at $shared_dir"

    # Finding the Logical unit number of the attached data disk
    disk_lun=$(az vm show --resource-group $resource_group_name --name $vm_name --query "storageProfile.dataDisks[?name=='$disk_name'].lun" -o tsv)
    

    #mounting data disk 
    ssh -o StrictHostKeyChecking=no "$USERNAME"@$PUBLIC_NFS_SERVER_IP <<EOF
    sudo apt -y update
    device_name="/dev/\$(ls -l /dev/disk/azure/scsi1 | grep -oE "lun$disk_lun -> ../../../[a-z]+" | awk -F'/' '{print \$NF}')"
    sudo mkfs.xfs \$device_name
    sudo mkdir -p "$shared_dir"
    sudo chmod 777 $shared_dir
    sudo mount \$device_name $shared_dir
    fstab_entry="\$device_name   $shared_dir   xfs   defaults   0   0"
    if ! grep -qF -- "\$fstab_entry" /etc/fstab; then
        echo "\$fstab_entry" | sudo tee -a /etc/fstab
    else
        echo "fstab entry already exists"
    fi
EOF
    jq ". += {"setup_nfs": true}" config.json > temp.json && mv temp.json config.json

fi

# adding model bazaar shared directory location
jq ". += {\"shared_dir\": \"$shared_dir\"}" config.json > temp.json && mv temp.json config.json