#!/bin/bash

CONFIG_FILE="/opt/bingo/config.yaml"

sed -i "s/\${DB_IP}/${DB_IP}/g" $CONFIG_FILE

#echo "set true dns";

echo "###   start check db   ###";

while ! nc -z ${DB_IP} 5432; do sleep 1; echo "check"; done;

echo "###   start bingo   ###";

app_started=false
prev_pid=0

current_t=$(date +"%Y-%m-%d %T")
echo "[$current_t] start bingo"
su - app -c './bingo run_server' &
sleep 0.25

prev_pid=$(ps aux | grep '[b]ingo run_server' | awk '$11 == "./bingo" {print $2}')
echo "PID ./bingo run_server: $prev_pid"
# echo "PID ./bingo run_server: $prev_pid"

echo "###   start healthy check   ###"

memory_limit=180000

while true; do
    mem=$(ps -p $prev_pid -o rss=)
    # echo "mem use: $mem"
    # echo "mem limit: $memory_limit"
    if [ "$mem" -gt "$memory_limit" ]; then
        kill -9 $prev_pid
    fi
    response=$(curl -s http://localhost:21999/ping)
    if [[ "$response" != "pong" ]]; then
        current_time=$(date +"%Y-%m-%d %T")
        echo "[$current_time] No pong received. Restarting ./bingo..."
        if ps -p "$prev_pid" > /dev/null; then
            kill -9 $prev_pid
        fi
        su - app -c './bingo run_server' &
        echo "PID ./bingo run_server: $prev_pid"
        sleep 0.2
        prev_pid=$(ps aux | grep '[b]ingo run_server' | awk '$11 == "./bingo" {print $2}')
        # echo "new PID ./bingo run_server: $prev_pid"
        app_started=true
    fi
    # echo "good ./bingo..."
    # memory_limit=$((mem * 11 / 10))
    sleep 0.2
done



# su - app -c './bingo prepare_db';
# su - app -c './bingo run_server';