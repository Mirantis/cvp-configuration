#!/bin/bash


# Set variables
HEAT_STACK_PREFIX=refapp
ITERATIONS_START=1
ITERATIONS_END=10
LOG_FILE="./run-refapp-density-${ITERATIONS_START}-${ITERATIONS_END}.log"
DATA_FILE="./run-refapp-density-${ITERATIONS_START}-${ITERATIONS_END}.csv"

# source CVP project credentials
source /opt/cmp-check/cvprc

start_test() {
  # Start test
  #export OS_CLOUD=openstack
  TEST_START_DATE=$(date +%s)
  echo "Test started at $(date)" >> ${LOG_FILE}
  echo "DATE;ITERATION_NUM;STACK_CREATION_DATE_DELTA;APP_REQUEST_TIME_ROOT;APP_REQUEST_TIME_POST_RECORD;APP_REQUEST_TIME_GET_RECORDS;APP_REQUEST_TIME_GET_RECORD" >> ${DATA_FILE}
  for ITERATION_NUM in `seq ${ITERATIONS_START} ${ITERATIONS_END}`
  do
    STACK_CREATION_START_DATE=$(date +%s)
    openstack stack create -t heat-templates/top.yaml ${HEAT_STACK_PREFIX}-${ITERATION_NUM} --wait | tee -a ${LOG_FILE}
    STACK_STATUS=$(openstack stack show ${HEAT_STACK_PREFIX}-${ITERATION_NUM} -f value -c stack_status)
    echo "$(date) ${HEAT_STACK_PREFIX}-${ITERATION_NUM} stack status is ${STACK_STATUS}" >> ${LOG_FILE}
    STACK_CREATION_END_DATE=$(date +%s)
    STACK_CREATION_DATE_DELTA=$((${STACK_CREATION_END_DATE} - ${STACK_CREATION_START_DATE}))
    if [ ${STACK_STATUS} == "CREATE_COMPLETE" ]
    then
      APP_URL=$(openstack stack show ${HEAT_STACK_PREFIX}-${ITERATION_NUM} -f value -c outputs | jq -cr '.[] | select(.output_key | contains("app_url")) | .output_value')
      # TODO implement awaiting for successful first curl
      sleep 30
      # Make sure that the app is already available
      curl -m 60 -s -o /dev/null ${APP_URL}
      EXIT_CODE=$(echo $?)
      if [ ${EXIT_CODE} != 0 ]
      then
        echo "curl command can't reach ${APP_URL} from ${HEAT_STACK_PREFIX}-${ITERATION_NUM} stack. Exit code ${EXIT_CODE}" >> ${LOG_FILE}
      fi

      UNIQ_LB_MEMBERS_COUNT=0
      RETRY_NUMBER=0
      while (( ${UNIQ_LB_MEMBERS_COUNT} != 3 && ${RETRY_NUMBER} <= 600 ))
      do
        UNIQ_LB_MEMBERS_COUNT=$(for LB_MEMBER in {1..3}; do curl -m 10 -s ${APP_URL} | jq -r .host; done | sort | uniq | wc -l)
        RETRY_NUMBER=$((${RETRY_NUMBER} + 1))
        sleep 1
      done
      if [ ${UNIQ_LB_MEMBERS_COUNT} != 3 ]
      then
        echo "$(date) There are only ${UNIQ_LB_MEMBERS_COUNT} LB members instead of 3 for ${APP_URL} LB endpoint from ${HEAT_STACK_PREFIX}-${ITERATION_NUM} stack." >> ${LOG_FILE}
      fi

      APP_REQUEST_TIME_ROOT=$(curl -m 10 -s -w %{time_total} -o /dev/null ${APP_URL})
      EXIT_CODE=$(echo $?)
      if [ ${EXIT_CODE} != 0 ]
      then
        echo "curl command can't reach ${APP_URL} from ${HEAT_STACK_PREFIX}-${ITERATION_NUM} stack. Exit code ${EXIT_CODE}" >> ${LOG_FILE}
      fi
      APP_REQUEST_TIME_POST_RECORD=$(curl -m 10 -s -w %{time_total} -X POST -H "Content-Type: application/json" --data '{"record": {"data": "spam"}}' -o /dev/null ${APP_URL}/records)
      EXIT_CODE=$(echo $?)
      if [ ${EXIT_CODE} != 0 ]
      then
        echo "curl command can't reach ${APP_URL}/records with POST requst from ${HEAT_STACK_PREFIX}-${ITERATION_NUM} stack. Exit code ${EXIT_CODE}" >> ${LOG_FILE}
      fi
      APP_REQUEST_TIME_GET_RECORDS=$(curl -m 10 -s -w %{time_total} -o /dev/null ${APP_URL}/records)
      EXIT_CODE=$(echo $?)
      if [ ${EXIT_CODE} != 0 ]
      then
        echo "curl command can't reach ${APP_URL}/records from ${HEAT_STACK_PREFIX}-${ITERATION_NUM} stack. Exit code ${EXIT_CODE}" >> ${LOG_FILE}
      fi
      APP_REQUEST_TIME_GET_RECORD=$(curl -m 10 -s -w %{time_total} -o /dev/null ${APP_URL}/record/1)
      EXIT_CODE=$(echo $?)
      if [ ${EXIT_CODE} != 0 ]
      then
        echo "curl command can't reach ${APP_URL}/records/1 from ${HEAT_STACK_PREFIX}-${ITERATION_NUM} stack. Exit code ${EXIT_CODE}" >> ${LOG_FILE}
      fi
      # Write the results to CSV
      echo "$(date);ITERATION-${ITERATION_NUM};${STACK_CREATION_DATE_DELTA};${APP_REQUEST_TIME_ROOT};${APP_REQUEST_TIME_POST_RECORD};${APP_REQUEST_TIME_GET_RECORDS};${APP_REQUEST_TIME_GET_RECORD}" >> ${DATA_FILE}
    else
      echo "$(date);ITERATION-${ITERATION_NUM};${STACK_STATUS}" >> ${DATA_FILE}
    fi
  done
  TEST_END_DATE=$(date +%s)
  TEST_DURATION=$((TEST_END_DATE - TEST_START_DATE))
  echo "$(date) Full test duration is ${TEST_DURATION} seconds" >> ${LOG_FILE}
}

main() {
  start_test
}

main