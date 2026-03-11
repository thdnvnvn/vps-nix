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

  mkdir -p ~/vps
  cd ~/vps

  # Pull Windows container
  if ! docker ps -a --format '{{.Names}}' | grep -qx 'windows-vm'; then
    docker pull dockurr/windows

    docker run -d \
      --name windows-vm \
      --device /dev/kvm \
      -p 8006:8006 \
      -e VERSION=win11 \
      -e RAM_SIZE=16G \
      -e CPU_CORES=8 \
      dockurr/windows
  else
    docker start windows-vm || true
  fi

  # Wait until Windows web panel is ready
  while ! nc -z localhost 8006; do sleep 2; done

  # Start Cloudflare tunnel
  nohup cloudflared tunnel --no-autoupdate --url http://localhost:8006 \
    > /tmp/cloudflared.log 2>&1 &

  sleep 10

  URL=""
  for i in {1..15}; do
    URL=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1)
    if [ -n "$URL" ]; then break; fi
    sleep 1
  done

  if [ -n "$URL" ]; then
    echo "========================================="
    echo "🌍 Windows VPS ready:"
    echo "$URL"
    echo "========================================="
  else
    echo "❌ Cloudflare tunnel failed"
  fi

  # Keep running
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
