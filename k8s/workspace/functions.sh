get_timestamp() {
  # "update_latest_report" depends on this pattern (it looks for '%Y' which
  # should match "20[0-9]{2} in this century).
  # Make changes in "update_latest_report" if you change timestamp here
	date +%Y-%m-%dT%H-%M
}

update_latest_report_to() {
  cp "$1" "$(echo $1|sed s/20[0-9]\\{2\\}.*/latest.html/)"
}