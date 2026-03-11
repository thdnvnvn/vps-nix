{ pkgs, ... }: {

channel = "stable-24.11";

packages = [
pkgs.docker
pkgs.cloudflared
pkgs.socat
pkgs.coreutils
pkgs.gnugrep
pkgs.netcat
pkgs.unzip
];

services.docker.enable = true;

idx.workspace.onStart = {
windows = ''
set -e

  mkdir -p /mnt/windows

  # tải image
  docker pull dockurr/windows

  # chạy Windows VM
  docker run -d \
    --name windows-vm \
    --device /dev/kvm \
    -p 8006:8006 \
    -e VERSION=win10 \
    -e RAM_SIZE=16G \
    -e CPU_CORES=8 \
    -v /mnt/windows:/storage \
    dockurr/windows

  # đợi web panel
  while ! nc -z localhost 8006; do
    sleep 3
  done

  # tạo cloudflare tunnel
  nohup cloudflared tunnel --no-autoupdate --url http://localhost:8006 \
    > /tmp/cloudflared.log 2>&1 &

  sleep 10

  URL=""
  for i in {1..20}; do
    URL=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1)
    if [ -n "$URL" ]; then break; fi
    sleep 1
  done

  echo "==============================="
  echo "🌍 Windows VPS:"
  echo "$URL"
  echo "==============================="

  while true; do sleep 60; done
'';

};

idx.previews = {
enable = true;
previews = {
windows = {
manager = "web";
command = [ "bash" "-lc" "socat TCP-LISTEN:$PORT,fork,reuseaddr TCP:127.0.0.1:8006" ];
};
};
};

}
