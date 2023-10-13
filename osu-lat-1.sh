#!/bin/bash

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

echo "IPs: $host_ip_1, $host_ip_2"

cat /host_sys/class/infiniband/*/ports/1/pkeys/0 > /pkey0.txt
cat /host_sys/class/infiniband/*/ports/1/pkeys/1 > /pkey1.txt

mpirun --allow-run-as-root -np 2 -H "$host_ip_1,$host_ip_2" /app/osu-micro-benchmarks-7.0.1/c/mpi/pt2pt/osu_latency > /osulat.txt

cat /pkey0.txt
cat /pkey1.txt
cat /osulat.txt
