#!/bin/bash
echo "Jenkins"

function log_status() {
  testidx=$1
  msg="$2"
  echo "$(date) | $msg" >> "$NS_WDIR/logs/TR${testidx}/rtg_trace.log"
}

function check_stop_and_start_test(){
flag=0
nsu_show_netstorm > /tmp/chk_stop_start_test.log.$$ 2>&1

  if [[ $? == 0 ]];then
    trnum=$(awk '{print $1}'  /tmp/chk_stop_start_test.log.$$ |tail -1)
    rm -f  /tmp/chk_stop_start_test.log.$$

    curpartition=$(cat $NS_WDIR/logs/TR${trnum}/.curPartition |tail -1 |cut -d = -f2)
    scenario=`ls -tr $NS_WDIR/logs/TR${trnum}/${curpartition}/*.conf | grep -v sorted | awk -F'/' '{print $NF}'`
    netstorm_pid=`ps -ef | grep $scenario | awk '($3 == 1) {print $2}'`
    last_rtg_file=$(ls -tr $NS_WDIR/logs/TR${trnum}/${curpartition}/rtgMessage.dat*|tail -1)
    #Last modified rtg file time in sec 
    last_modified_time_of_rtg_file=$( stat -c '%Y' $last_rtg_file)
    log_status "$trnum" "Current Partition: ${curpartition}, Latest RTG file: ${last_rtg_file}, Last modified: ${last_modified_time_of_rtg_file}"
    #Current time in sec
    current_date_in_sec=$(date +%s)
    timediff=$(($current_date_in_sec - $last_modified_time_of_rtg_file))
    log_status "$trnum" "Current Timestamp: $current_date_in_sec, timdiff: $timediff"
    if [[ $timediff -gt 300 ]];then
      log_status "$trnum" "Time diff is greater than 300, stopping test"
      while true; do
        if [ $flag -eq 0 ]; then
          kill -11 $netstorm_pid
          flag=1
        fi

        nsu_stop_test -s $trnum
        sleep 5
        nsu_show_netstorm > /dev/null 2>&1
        if [[ $? != 0 ]];then
          log_status "$trnum" "Test has been stopped. Trying to restart"
          break
        fi
      done
      sleep 10
      #Starting the CM Test again
      nsu_start_test -n mosaic_stress_as1 -S g

    fi
  fi
}

while true
do
  check_stop_and_start_test
  sleep 600
done
