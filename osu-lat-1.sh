#!/bin/bash

set -euo pipefail

log_information() {
    printf '[INFO] %s\n' "$1"
}

get_adjacent_ip() {
    local -r ip=$1
    local -r increment=$2
    local adjacent_ip=$(echo "$ip" | awk -v increment="$increment" -F '.' '{$4+=increment; print}' OFS='.')
    echo "$adjacent_ip"
}

ping_ip() {
    local -r ip=$1
    ping -c 1 "$ip" >/dev/null 2>&1
    echo $?
}

set_private_key() {
    az login --identity --allow-no-subscriptions
    local -r delimiter=$1
    # Get secret value
    local -r secret=$(az keyvault secret show \
        --vault-name "$2-kv" \
        --name "$3" \
        --query "value" \
        -o json | jq -r .)
    # Replace delimiter with newline
    local -r private_key=$(echo "$secret" | sed "s/$delimiter/\\n/g")
    # Write the formatted string to the output file
    printf '%s\n' "$private_key" >/app/private-key.pem

    # Create SSH directory if it doesn't exist
    mkdir -p /root/.ssh

    # Set the SSH key as the default authentication for remote hosts
    cp /app/private-key.pem /root/.ssh/id_rsa
    chmod 600 /root/.ssh/id_rsa
}

add_known_hosts() {
    # Add both hosts to the list of known hosts
    touch /root/.ssh/known_hosts
    chmod 644 /root/.ssh/known_hosts
    declare -r -a host_ips=("$1" "$2")
    # Loop through the array and add each host to the known_hosts file
    for ip in "${host_ips[@]}"; do
        if ! ssh-keygen -F "$ip" >/dev/null 2>&1; then
            ssh-keyscan -H "$ip" >> /root/.ssh/known_hosts
        fi
    done
}

main() {
    # if $1 is not provided, show usage, then exit
    if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]]; then
        printf '\nMissing arguments. Exiting...\n' >&2
        printf '\nExample usage:\n%s <pkey-str-delimiter> <aks-cluster-name> <secret-name> <osu-micro-benchmarks-(version-number)>\n' "$0"
        exit 1
    fi

    readonly host_ip_1=$(hostname -i)
    log_information "Current IP: $host_ip_1"

    readonly next_ip=$(get_adjacent_ip "$host_ip_1" 1)
    if ping_ip "$next_ip" >/dev/null; then
        log_information "Next IP ($next_ip) responded successfully"
        local host_ip_2=$next_ip
    fi

    readonly prev_ip=$(get_adjacent_ip "$host_ip_1" -1)
    if ping_ip "$prev_ip" >/dev/null; then
        log_information "Previous IP ($prev_ip) responded successfully"
        host_ip_2=$prev_ip
    fi

    log_information "IPs: $host_ip_1, $host_ip_2"

    log_information "Setting private key..."
    set_private_key "$1" "$2" "$3"

    log_information "Adding hosts to known hosts..."
    add_known_hosts "$host_ip_1" "$host_ip_2"

    log_information "Getting IB PKey for port 1 slot 0... (cat /host_sys/class/infiniband/*/ports/1/pkeys/0 >/app/pkey0.txt)"
    cat /host_sys/class/infiniband/*/ports/1/pkeys/0 >/app/pkey0.txt

    log_information "Getting IB PKey for port 1 slot 1... (cat /host_sys/class/infiniband/*/ports/1/pkeys/1 >/app/pkey1.txt)"
    cat /host_sys/class/infiniband/*/ports/1/pkeys/1 >/app/pkey1.txt

    log_information "Running OSU MPI latency test... (mpirun --allow-run-as-root -np 2 -H \"$host_ip_1,$host_ip_2\" /app/$4/c/mpi/pt2pt/osu_latency >/app/osulat.txt)"
    mpirun --allow-run-as-root -np 2 -H "$host_ip_1,$host_ip_2" /app/"$4"/c/mpi/pt2pt/osu_latency >/app/osulat.txt

    printf '%s\n' "$(cat /app/pkey0.txt)"
    printf '%s\n' "$(cat /app/pkey1.txt)"
    printf '%s\n' "$(cat /app/osulat.txt)"
}

main "$@"
