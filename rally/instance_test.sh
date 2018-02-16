additive_dd() {
    sudo sh -c "echo '127.0.0.1 $(hostname)' >> /etc/hosts"
    sudo mkfs.ext4 /dev/vdb > /dev/null
    sudo mkdir -p /mnt/volume
    sudo mount /dev/vdb /mnt/volume
    
    write_4k_res=`sudo -u root dd if=/dev/zero of=/mnt/volume/write_4k.dat oflag=direct bs=4k count=262144 2>&1`
    local write_4k=`echo $write_4k_res |  awk '{print $14}'`

    write_1m_res=`sudo -u root dd if=/dev/zero of=/mnt/volume/write_1m.dat oflag=direct bs=1M count=1024 2>&1`
    local write_1m=`echo $write_1m_res |  awk '{print $14}'`

    write_1g_res=`sudo -u root dd if=/dev/zero of=/mnt/volume/write_1g.dat oflag=direct bs=1G count=1 2>&1`
    local write_1g=`echo $write_1g_res |  awk '{print $14}'`
    cat << EOF
    {
      "title": "Write 4k, 1M, 1G file",
      "description": "description",
      "chart_plugin": "StackedArea",
      "data": [
        ["write_4k", ${write_4k}],
        ["write_1M", ${write_1m}],
        ["write_1G", ${write_1g}]]
    }

EOF
}

cat << EOF
{
  "additive": [$(additive_dd)],
  "complete": []
}
EOF
