#!/bin/sh

# Count devices that are less than 8 hours old
DEVICE_AGE_HOURS=8

# Timeout devices that are more than 12 hours old
DEVICE_TIMEOUT_HOURS=12

# Device name, e.g. "eth0"
DEVICE=""


if [ $DEVICE_AGE_HOURS -gt $DEVICE_TIMEOUT_HOURS ]; then
  echo "$0: DEVICE_AGE_HOURS ($DEVICE_AGE_HOURS) must be lower DEVICE_TIMEOUT_HOURS ($DEVICE_TIMEOUT_HOURS)" >&2
  exit 1
fi

# lines of "<mac_addr> <first_seen> <last_seen>""
FILE="/tmp/guest_counter.db"
now=$(date +%s)
age=$((now - 60 * 60 * DEVICE_AGE_HOURS))
timeout=$((now - 60 * 60 * DEVICE_TIMEOUT_HOURS))
cur_entries="$(cat $FILE 2> /dev/null)"
new_entries=""
count=0

handle_entry() {
  local multiple=$1
  local mac_addr=$2
  local first_seen=${3:-$now}
  local last_seen=${4:-$now}

  # Multiple entries mean the entry got from iptools => active device
  if [ $multiple -gt 1 ]; then
    last_seen=$now
  fi

  # Only handle devices that did not timeout and have a mac addr of valid length
  if [ $last_seen -gt $timeout -a ${#mac_addr} -eq 17 ]; then
    # Only output active devices that are younger than a certain age
    if [ $last_seen -eq $now -a $first_seen -gt $age ]; then
      count=$((count + 1))
    fi

    # Append new entry
    new_entries+="$mac_addr $first_seen $last_seen
"
  fi
}

# Split by newline
IFS="
"
for entry in $( (ip neighbor show ${DEVICE:+dev DEVICE} | cut -s -d' ' -f5; echo $cur_entries;) | sort -r | uniq -c -w 17)
do
  # Split by space
  IFS=" "

  handle_entry $entry
done

# Backup entries for next call
echo -n "$new_entries" > $FILE

echo $count

exit 0
