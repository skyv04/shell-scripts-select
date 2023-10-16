#!/bin/bash

set -e

# if $1 is not provided, show usage, then exit
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    echo -e "\nMissing arguments. Exiting..." >&2
    echo -e "\nExample usage:\n$0 <pkey-str-delimiter> <aks-cluster-name> <secret-name> <osu-micro-benchmarks-(version-number)>\n"
    exit 1
fi

log_information() {
    echo "[INFO] $1"
}

get_adjacent_ip() {
    local ip=$1
    local increment=$2
    local adjacent_ip=$(echo $ip | awk -v increment=$increment -F '.' '{$4+=increment; print}' OFS='.')
    echo $adjacent_ip
}

ping_ip() {
    local ip=$1
    ping -c 1 $ip >/dev/null 2>&1
    echo $?
}

host_ip_1=$(hostname -i)
log_information "Current IP: $host_ip_1"

next_ip=$(get_adjacent_ip $host_ip_1 1)
if [ $(ping_ip $next_ip) -eq 0 ]; then
    log_information "Next IP ($next_ip) responded successfully"
    host_ip_2=$next_ip
fi

prev_ip=$(get_adjacent_ip $host_ip_1 -1)
if [ $(ping_ip $prev_ip) -eq 0 ]; then
    log_information "Previous IP ($prev_ip) responded successfully"
    host_ip_2=$prev_ip
fi

log_information "IPs: $host_ip_1, $host_ip_2"

set_private_key() {
    az login --identity --no-subscription >/dev/null 2>&1
    local delimiter=$1
    # Get secret value
    local secret=$(az keyvault secret show \
        --vault-name "$2-kv" \
        --name "$3" \
        --query "value" \
        -o json | jq -r .)
    # Replace delimiter with newline
    local privateKey=$(echo "$secret" | sed "s/$delimiter/\\n/g")
    # Write the formatted string to the output file
    echo -e "$privateKey" >/app/private-key.pem

    # Create SSH directory if it doesn't exist
    # mkdir -p /home/azureuser/.ssh
    mkdir -p /root/.ssh

    # Set the SSH key as the default authentication for remote hosts
    # cp /home/azureuser/private-key.pem /home/azureuser/.ssh/id_rsa
    cp /app/private-key.pem /root/.ssh/id_rsa
    # chmod 600 /home/azureuser/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa

    # chown azureuser:azureuser /home/azureuser/.ssh/id_rsa
    # chown azureuser:azureuser /root/.ssh/id_rsa

    # Clean
    # rm -f /app/private-key.pem
}

add_known_hosts() {
    # Add both hosts to the list of known hosts
    # touch /home/azureuser/.ssh/known_hosts
    # chmod 777 /home/azureuser/.ssh/known_hosts
    touch /root/.ssh/known_hosts
    chmod 777 /root/.ssh/known_hosts
    HOST_IPS=( "$1" "$2" )
    # Loop through the array and add each host to the known_hosts file
    for ip in "${HOST_IPS[@]}"; do
        # ssh-keygen -F "$ip" >/dev/null 2>&1 || ssh-keyscan "$ip" >> /home/azureuser/.ssh/known_hosts 2>/dev/null
        ssh-keygen -F "$ip" >/dev/null 2>&1 || ssh-keyscan "$ip" >> /root/.ssh/known_hosts 2>/dev/null
    done
}

log_information "Setting private key..."
set_private_key $1 $2 $3

log_information "Adding hosts to known hosts..."
add_known_hosts $host_ip_1 $host_ip_2

log_information "Running OSU MPI latency test... (cat /host_sys/class/infiniband/*/ports/1/pkeys/0 >/app/pkey0.txt)"
cat /host_sys/class/infiniband/*/ports/1/pkeys/0 >/app/pkey0.txt

log_information "Running OSU MPI latency test... (cat /host_sys/class/infiniband/*/ports/1/pkeys/1 >/app/pkey1.txt)"
cat /host_sys/class/infiniband/*/ports/1/pkeys/1 >/app/pkey1.txt

log_information "Running OSU MPI latency test... (mpirun --allow-run-as-root -np 2 -H \"$host_ip_1,$host_ip_2\" /app/$4/c/mpi/pt2pt/osu_latency >/app/osulat.txt)"
mpirun --allow-run-as-root -np 2 -H "$host_ip_1,$host_ip_2" /app/$1/c/mpi/pt2pt/osu_latency >/app/osulat.txt

cat /app/pkey0.txt
cat /app/pkey1.txt
cat /app/osulat.txt
