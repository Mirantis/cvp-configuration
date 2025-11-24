get_timestamp() {
  # "update_latest_report" depends on this pattern (it looks for '%Y' which
  # should match "20[0-9]{2} in this century).
  # Make changes in "update_latest_report" if you change timestamp here
	date +%Y-%m-%dT%H-%M
}

update_latest_report_to() {
  cp "$1" "$(echo $1|sed s/20[0-9]\\{2\\}.*/latest.html/)"
}

check_cluster_deployment_exists() {
    local cluster_name="$1"
    echo ""
    echo "Checking if ClusterDeployment '$cluster_name' exists..."
    if ! kubectl get cld -A -o name | awk -F'/' '{print $NF}' | grep -qx "$cluster_name"; then
        echo "Error: ClusterDeployment '$cluster_name' not found in any namespace"
        return 1
    fi
    echo -e "ClusterDeployment '$cluster_name' found"
    return 0
}

check_file_exists() {
    local path="$1"
    local desc="$2"
    if [[ ! -f "$path" ]]; then
        echo "Error: $desc file not found at $path"
        return 1
    fi
}

txt2html_net_ping_report() {
    local in="$1"
    local cluster_name="$2"
    local out="$3"

    [[ -z "$in" ]] && { echo "Usage: txt2html_net_ping_report <input.txt> [cluster_name] [output.html]"; return 2; }
    [[ ! -f "$in" ]] && { echo "No such file: $in"; return 2; }

    if [[ -z "$out" ]]; then
        out="${in%.txt}.html"
        [[ "$out" == "$in" ]] && out="$in.html"
    fi
    mkdir -p "$(dirname "$out")" || return 1

    local ts
    ts="$(get_timestamp)"
    local cluster_esc_name="$cluster_name"
    cluster_esc_name="${cluster_esc_name//&/&amp;}"
    cluster_esc_name="${cluster_esc_name//</&lt;}"
    cluster_esc_name="${cluster_esc_name//>/&gt;}"
    local title="Network Ping Report"
    [[ -n "$cluster_esc_name" ]] && title="Network Ping Report [$cluster_esc_name]"

    {

    cat <<EOF
<!doctype html>
<html lang="en"><head>
<meta charset="utf-8">
<title>$title</title>
<style>
  body { font:14px/1.45 system-ui, -apple-system, Segoe UI, Roboto, sans-serif; margin:20px; }
  .summary { font-weight:600; margin:0 0 8px; }
  .net     { color:#0366d6; font-weight:600; }
  .from    { color:#555; font-weight:600; display:block; margin-top: 18px; margin-bottom: -12px; }
  .pass    { color:#1a7f37; font-weight:600; }
  .fail    { color:#e53935; font-weight:600; }
  pre      { background:#fafafa; border:1px solid #e5e5e5; padding:12px; overflow:auto; }
</style>
</head><body>
<h2>$title</h2>
<p style="color: gray; font-style: italic; font-size: 10px;">Generated at $ts</p>
<pre>
EOF

    awk '
    function esc(s){ gsub("&","&amp;",s); gsub("<","&lt;"); gsub(">","&gt;"); return s }
    {
      raw=$0
      line=esc(raw)
      gsub(/\+ PASS:/,"<span class=\"pass\">+ PASS:</span>",line)
      gsub(/\- FAIL:/,"<span class=\"fail\">- FAIL:</span>",line)
      if (raw ~ /^# Summary/) { print "<span class=\"summary\">" line "</span>"; next }
      if (raw ~ /^--->/)      { print "<span class=\"net\">"     line "</span>";   next }
      if (raw ~ /^=+/)        { print "<span class=\"from\">"    line "</span>";   next }
      print line
    }' "$in"

    cat <<'EOF'
</pre>
</body></html>
EOF
    } > "$out"

    echo "Done: $out"
}
