#!/usr/bin/env bash
# Asssume traffic server is built and installed

if [[ "$#" = 5 ]]; then
  trace=$1
  alg=$2
  real_time=$3
  test_bed=$4
  trail=$5
elif [[ "$#" = 0 ]]; then
  trace=wiki_1400m_4mb
#  trace=ntg1_400m_4mb
#  alg=ats
  alg=fifo
#  alg=wlc
  real_time=0
  test_bed=pni
  trail=0
else
    echo "Illegal number of parameters"
    exit 1
fi

n_origin_threads=1024
#TODO: make sure snapshot id is more recent
native_ats_snapshot="native-v2"
zhenyu_ats_snapshot="zhenyus-v5"

suffix=${trace}_${alg}_${real_time}_${test_bed}_${trail}

if [[ ${alg} = "wlc" ]]; then
  snapshot_id=$zhenyu_ats_snapshot
  if [[ ${trace} = 'wiki_1400m_4mb' ]]; then
    ram_size=28998676480
    memory_window=469762048
  else
    ram_size=31006543872
    memory_window=100663296
  fi
elif [[ ${alg} = "lru" ]]; then
  snapshot_id=$zhenyu_ats_snapshot
  if [[ ${trace} = 'wiki_1400m_4mb' ]]; then
    ram_size=32177463296
  else
    ram_size=32153886720
  fi
else
  snapshot_id=$native_ats_snapshot
  ram_size=34359738368
fi

if [[ ${trace} = 'wiki_1400m_4mb' ]]; then
  ssd_config="--local-ssd=interface=NVME --local-ssd=interface=NVME --local-ssd=interface=NVME --local-ssd=interface=NVME"
  cache_size=549755813888
  n_warmup_client=180
  n_client=1024
else
  ssd_config="--local-ssd=interface=NVME --local-ssd=interface=NVME --local-ssd=interface=NVME --local-ssd=interface=NVME --local-ssd=interface=NVME --local-ssd=interface=NVME --local-ssd=interface=NVME --local-ssd=interface=NVME"
  cache_size=1099511627776
  n_warmup_client=1024
  n_client=1024
fi


if [[ ${test_bed} = 'gcp' ]]; then
  #create client
  client_name=client-${trace:0:1}-${alg}-${real_time}-${trail}

  echo $client_name
  gcloud compute --project "analog-delight-252816" disks create $client_name --size "128" --zone "us-east4-c" --source-snapshot $snapshot_id --type "pd-standard"

  gcloud beta compute --project=analog-delight-252816 instances create $client_name --zone=us-east4-c --machine-type=n1-standard-16 --subnet=default --no-address --network-tier=PREMIUM --metadata=ssh-keys=zhenyus:ssh-rsa\ AAAAB3NzaC1yc2EAAAADAQABAAABAQCn207dzUfLZHccGWnk4gl\+76QU2D05ausXsqBNTMp9BvJeXEvbcSkauSsA1ih73nt2yI4yOs94SfwmXBa7ZNAp4nEy2mLDywLFjN/qhmWd4z1ucqw4mD5mJCHOFBWPimlWZmTpTkmauNFnfbGdmP2CspR2JJaNUORX/TPo0Xvj1aNLwfJn76voXDrPDaX5QqiOlhVRZJNJvWX/ybDLyllsh0eNAkVfTqNzyvKK/Ms7M3yKcicYccJBwY35rS0rxvpw9i9v5pvi\+81taXA5HX9KkjtA/keGcfhN95VO2vpVXmSWmYnsO5zv42xKzfC0USICV3fssdXj/H2bvvWrOKDD\ zhenyus --maintenance-policy=MIGRATE --service-account=78652309126-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --disk=name=${client_name},device-name=${client_name},mode=rw,boot=yes,auto-delete=yes --reservation-affinity=any

  client_ip_internal=$( gcloud compute instances describe $client_name --format='get(networkInterfaces[0].networkIP)' )

  echo "$client_ip_internal"

  #create origin
  origin_name=origin-${trace:0:1}-${alg}-${real_time}-${trail}
  echo $origin_name
  gcloud compute --project "analog-delight-252816" disks create $origin_name --size "128" --zone "us-east4-c" --source-snapshot $snapshot_id --type "pd-standard"

  gcloud beta compute --project=analog-delight-252816 instances create $origin_name --zone=us-east4-c --machine-type=n1-standard-16 --subnet=default --no-address --network-tier=PREMIUM --metadata=ssh-keys=zhenyus:ssh-rsa\ AAAAB3NzaC1yc2EAAAADAQABAAABAQCn207dzUfLZHccGWnk4gl\+76QU2D05ausXsqBNTMp9BvJeXEvbcSkauSsA1ih73nt2yI4yOs94SfwmXBa7ZNAp4nEy2mLDywLFjN/qhmWd4z1ucqw4mD5mJCHOFBWPimlWZmTpTkmauNFnfbGdmP2CspR2JJaNUORX/TPo0Xvj1aNLwfJn76voXDrPDaX5QqiOlhVRZJNJvWX/ybDLyllsh0eNAkVfTqNzyvKK/Ms7M3yKcicYccJBwY35rS0rxvpw9i9v5pvi\+81taXA5HX9KkjtA/keGcfhN95VO2vpVXmSWmYnsO5zv42xKzfC0USICV3fssdXj/H2bvvWrOKDD\ zhenyus --maintenance-policy=MIGRATE --service-account=78652309126-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --disk=name=${origin_name},device-name=${origin_name},mode=rw,boot=yes,auto-delete=yes --reservation-affinity=any

  origin_ip_internal=$( gcloud compute instances describe $origin_name --format='get(networkInterfaces[0].networkIP)' )

  echo "$origin_ip_internal"

  #create proxy
  proxy_name=proxy-${trace:0:1}-${alg}-${real_time}-${trail}
  echo $proxy_name
  gcloud compute --project "analog-delight-252816" disks create $proxy_name --size "128" --zone "us-east4-c" --source-snapshot $snapshot_id --type "pd-standard"

  gcloud beta compute --project=analog-delight-252816 instances create $proxy_name --zone=us-east4-c --machine-type=n1-standard-64 --subnet=default --network-tier=PREMIUM --metadata=ssh-keys=zhenyus:ssh-rsa\ AAAAB3NzaC1yc2EAAAADAQABAAABAQCn207dzUfLZHccGWnk4gl\+76QU2D05ausXsqBNTMp9BvJeXEvbcSkauSsA1ih73nt2yI4yOs94SfwmXBa7ZNAp4nEy2mLDywLFjN/qhmWd4z1ucqw4mD5mJCHOFBWPimlWZmTpTkmauNFnfbGdmP2CspR2JJaNUORX/TPo0Xvj1aNLwfJn76voXDrPDaX5QqiOlhVRZJNJvWX/ybDLyllsh0eNAkVfTqNzyvKK/Ms7M3yKcicYccJBwY35rS0rxvpw9i9v5pvi\+81taXA5HX9KkjtA/keGcfhN95VO2vpVXmSWmYnsO5zv42xKzfC0USICV3fssdXj/H2bvvWrOKDD\ zhenyus --maintenance-policy=MIGRATE --service-account=78652309126-compute@developer.gserviceaccount.com --scopes=https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append --disk=name=${proxy_name},device-name=${proxy_name},mode=rw,boot=yes,auto-delete=yes ${ssd_config} --reservation-affinity=any

  proxy_ip_internal=$( gcloud compute instances describe $proxy_name --format='get(networkInterfaces[0].networkIP)' )
  proxy_ip_external=$( gcloud compute instances describe $proxy_name --format='get(networkInterfaces[0].accessConfigs[0].natIP)' )

  echo "$proxy_ip_external"
  echo "$proxy_ip_internal"

  ssh-keygen -R "$proxy_ip_external"
  ssh-keygen -R "$client_ip_internal"
  ssh-keygen -R "$origin_ip_internal"
  echo "wait until the servers ready"
  until ssh ${proxy_ip_external} 'echo 1>/dev/null'; do
    echo "waiting proxy"
    sleep 5
  done

  until ssh -o ProxyJump=${proxy_ip_external} $client_ip_internal 'echo 1>/dev/null'; do
    echo "waiting client"
    sleep 5
  done

  until ssh -o ProxyJump=${proxy_ip_external} $origin_ip_internal 'echo 1>/dev/null'; do
    echo "waiting origin"
    sleep 5
  done

  echo "updating repo"
  ssh "$proxy_ip_external" "cd ~/webtracereplay/origin && git pull && make"
  ssh "$proxy_ip_external" "cd ~/webtracereplay/client && git pull && make"
  ssh -o ProxyJump=${proxy_ip_external} $client_ip_internal "cd ~/webtracereplay/client && git pull && make"

  #change config based on trace, alg: hosting.config, records.config, storage.config, volume.config
  #use single SSD
  if [[ ${trace} = "wiki_1400m_4mb" ]]; then
    ssh "$proxy_ip_external" "cp ~/webtracereplay/tsconfig_backup/storage_4.config ~/webtracereplay/tsconfig_gcp/storage.config"
  elif [[ ${trace} = "ntg1_400m_4mb" ]]; then
    ssh "$proxy_ip_external" "cp ~/webtracereplay/tsconfig_backup/storage_8.config ~/webtracereplay/tsconfig_gcp/storage.config"
  else
    echo "error: no trace found"
    exit 1
  fi

  echo "set proxy SSD permission"
  ssh "$proxy_ip_external" 'sudo apt-get update && sudo apt-get install mdadm --no-install-recommends'

  if [[ ${trace} = "wiki_1400m_4mb" ]]; then
    ssh "$proxy_ip_external" 'sudo mdadm --create /dev/md0 --level=0 --raid-devices=4 /dev/nvme0n1 /dev/nvme0n2 /dev/nvme0n3 /dev/nvme0n4'
  elif [[ ${trace} = "ntg1_400m_4mb" ]]; then
    ssh "$proxy_ip_external" 'sudo mdadm --create /dev/md0 --level=0 --raid-devices=8 /dev/nvme0n1 /dev/nvme0n2 /dev/nvme0n3 /dev/nvme0n4 /dev/nvme0n5 /dev/nvme0n6 /dev/nvme0n7 /dev/nvme0n8'
  fi

  ssh "$proxy_ip_external" 'sudo chmod 777 /dev/md0'
  home=/home/zhenyus

elif [[ ${test_bed} = "pni" ]]; then
  proxy_ip_external=cache_proxy
  proxy_ip_internal=10.1.255.253
  client_ip_internal=10.1.255.251
  origin_ip_internal=10.1.255.250

  echo "updating repo"
  ssh "$proxy_ip_external" "cd ~/webtracereplay/origin && git pull && make"
  ssh "$proxy_ip_external" "cd ~/webtracereplay/client && git pull && make"
  ssh -o ProxyJump=${proxy_ip_external} $client_ip_internal "cd ~/webtracereplay/client && git pull && make"

  #use single SSD
  ssh "$proxy_ip_external" "cp ~/webtracereplay/tsconfig_backup/storage_pni.config /opt/ts/etc/trafficserver/storage.config"
  home=/usr/people/zhenyus

  echo "trimming SSD"
  ssh "$proxy_ip_external" "/usr/sbin/blkdiscard /dev/fioa"

else
   echo "wrong test_bed"
   exit 1
fi


#change config based on trace, alg: hosting.config, records.config, storage.config, volume.config
ssh "$proxy_ip_external" "sed -i 's/^CONFIG proxy.config.cache.ram_cache.size.*/CONFIG proxy.config.cache.ram_cache.size INT "${ram_size}"/g' /opt/ts/etc/trafficserver/records.config"
if [[ ${alg} = "wlc" ]]; then
	ssh "$proxy_ip_external" "sed -i 's/^.*CONFIG proxy.config.cache.vdisk_cache.algorithm.*/CONFIG proxy.config.cache.vdisk_cache.algorithm STRING WLC/g' /opt/ts/etc/trafficserver/records.config"
	ssh "$proxy_ip_external" "sed -i 's/^CONFIG proxy.config.cache.vdisk_cache.memory_window.*/CONFIG proxy.config.cache.vdisk_cache.memory_window INT "${memory_window}"/g' /opt/ts/etc/trafficserver/records.config"
elif [[ ${alg} = "lru" ]]; then
	ssh "$proxy_ip_external" "sed -i 's/^.*CONFIG proxy.config.cache.vdisk_cache.algorithm.*/CONFIG proxy.config.cache.vdisk_cache.algorithm STRING LRU/g' /opt/ts/etc/trafficserver/records.config"
elif [[ ${alg} = "fifo" ]]; then
	ssh "$proxy_ip_external" "sed -i 's/^.*CONFIG proxy.config.cache.vdisk_cache.algorithm.*/CONFIG proxy.config.cache.vdisk_cache.algorithm STRING FIFO/g' /opt/ts/etc/trafficserver/records.config"
elif [[ ${alg} = "ats" ]]; then
	ssh "$proxy_ip_external" "sed -i 's/^.*CONFIG proxy.config.cache.vdisk_cache.algorithm.*/#CONFIG proxy.config.cache.vdisk_cache.algorithm STRING/g' /opt/ts/etc/trafficserver/records.config"
else
  echo "error: no algorithm found"
  exit 1
fi

echo "set client latency"
ssh -o ProxyJump=${proxy_ip_external} $client_ip_internal bash ${home}/webtracereplay/scripts/instrument_latency.sh $proxy_ip_internal


echo "starting origin"
ssh -o ProxyJump=${proxy_ip_external} $origin_ip_internal bash ${home}/webtracereplay/scripts/start_origin.sh $origin_ip_internal ${trace} ${n_origin_threads} 0 warmup ${suffix}
exit 0
#ssh -o ProxyJump=${proxy_ip_external} "$origin_ip_internal" "sudo nginx -s stop"
#ssh -o ProxyJump=${proxy_ip_external} "$origin_ip_internal" "sudo nginx -c ~/webtracereplay/server/nginx.conf"
#ssh -o ProxyJump=${proxy_ip_external} "$origin_ip_internal" pkill -f origin
#ssh -o ProxyJump=${proxy_ip_external} "$origin_ip_internal" "cd ~/webtracereplay/origin && spawn-fcgi -a 127.0.0.1 -p 9000 -n ./origin ../"${trace}"_origin.tr "${n_origin_threads}" 0 > /tmp/proxy_0.log" &


echo "use remote proxy"
ssh "$proxy_ip_external" ${home}/webtracereplay/scripts/remap_remote.sh $origin_ip_internal

#restart
ssh "$proxy_ip_external" 'rm /opt/ts/var/log/trafficserver/*'
ssh "$proxy_ip_external" "pkill -9 -f trafficserver"
ssh "$proxy_ip_external" "/opt/ts/bin/traffic_server -Cclear"
ssh "$proxy_ip_external" "/opt/ts/bin/trafficserver restart"

echo "warmuping up"
ssh "$proxy_ip_external" pkill -f client
ssh "$proxy_ip_external" 'rm -f ~/webtracereplay/log/*'

echo "start measuring segment stat"
ssh "$proxy_ip_external" 'pkill -9 -f segment_static'
ssh "$proxy_ip_external" ${home}/webtracereplay/scripts/segment_static.sh warmup_${suffix} ${test_bed} &
#TODO: remove this timeout later
ssh "$proxy_ip_external" "cd ~/webtracereplay/client; ./client ../"${trace}"_warmup.tr "${n_warmup_client}" localhost:6000/ ../log/throughput_warmup_"${suffix}".log ../log/latency_warmup_"${suffix}".log 0 >/dev/null"
sleep 15 # for sync
echo "stop measuring segment stat"
ssh "$proxy_ip_external" 'pkill -9 -f segment_static'
ssh "$proxy_ip_external" 'tail -n 10000 /opt/ts/var/log/trafficserver/small.log' > /home/zhenyus/gcp_log/small_warmup_${suffix}.log

echo "switch to remote mode"
ssh -o ProxyJump=${proxy_ip_external} "$origin_ip_internal" pkill -f origin
ssh -o ProxyJump=${proxy_ip_external} "$origin_ip_internal" "cd ~/webtracereplay/origin && spawn-fcgi -a 127.0.0.1 -p 9000 -n ./origin ../"${trace}"_origin.tr "${n_origin_threads}" 100 > /tmp/proxy_100.log" &

echo "start measuring segment stat"
#: record segment byte miss/req
ssh "$proxy_ip_external" 'pkill -9 -f segment_static'
ssh "$proxy_ip_external" ${home}/webtracereplay/scripts/segment_static.sh eval_${suffix} ${test_bed}&

echo "using remote client"
ssh -o ProxyJump=${proxy_ip_external} $client_ip_internal pkill -f client
#TODO: make time out to be max 1 hour
ssh -o ProxyJump=${proxy_ip_external} $client_ip_internal "cd ~/webtracereplay/client; timeout 3600 ./client ../"${trace}"_eval.tr "${n_client}" "${proxy_ip_internal}":6000/ ../log/throughput_eval_"${suffix}".log ../log/latency_eval_"${suffix}".log "${real_time}" > /dev/null"
#ssh -o ProxyJump=${proxy_ip_external} $client_ip_internal "cd /home/zhenyus/webtracereplay/client; timeout 3600 ./client ../"${trace}"_eval.tr "${n_client}" "${proxy_ip_internal}":6000/ ../log/throughput_eval_"${suffix}".log ../log/latency_eval_"${suffix}".log "${real_time}
sleep 15 # for sync
echo "stop measuring segment stat"
ssh "$proxy_ip_external" 'pkill -9 -f segment_static'
ssh "$proxy_ip_external" 'tail -n 10000 /opt/ts/var/log/trafficserver/small.log' > /home/zhenyus/gcp_log/small_eval_${suffix}.log

echo "downloading..."
scp -3 -o ProxyJump=${proxy_ip_external} "$origin_ip_internal":/tmp/proxy_0.log ~/gcp_log/origin_warmup_${suffix}.log
scp -3 -o ProxyJump=${proxy_ip_external} "$origin_ip_internal":/tmp/proxy_100.log ~/gcp_log/origin_eval_${suffix}.log

scp -3 -o ProxyJump=${proxy_ip_external} "$client_ip_internal":~/webtracereplay/log/* ~/gcp_log/

scp -3 "$proxy_ip_external":/opt/ts/var/log/trafficserver/diag.log ~/gcp_log/
rsync "$proxy_ip_external":~/webtracereplay/log/* ~/gcp_log/
#TODO: multiple scp can happens at the same time
rsync ~/gcp_log/* fat:~/webcachesim/gcp_log/

echo "deleting vms"

if [[ ${test_bed} = 'gcp' ]]; then
  #TODO: enable deleting
  gcloud compute instances delete --quiet $origin_name
  gcloud compute instances delete --quiet $client_name
  gcloud compute instances delete --quiet $proxy_name
elif [[ ${test_bed} = "pni" ]]; then
  echo ${suffix} finish
else
   echo "wrong test_bed"
   exit 1
fi

