{ pkgs, ... }: {

  channel = "stable-24.11";

  packages = [
    pkgs.docker
    pkgs.cloudflared
    pkgs.socat
    pkgs.coreutils
    pkgs.gnugrep
    pkgs.sudo
    pkgs.unzip
    pkgs.netcat
  ];

  services.docker.enable = true;

  idx.workspace.onStart = {
    novnc = ''
      set -e

      mkdir -p ~/vps
      cd ~/vps

      # cleanup 1 lần
      if [ ! -f /home/user/.cleanup_done ]; then
        rm -rf /home/user/.gradle/* /home/user/.emu/* || true
        touch /home/user/.cleanup_done
      fi

      # pull container
      if ! docker ps -a --format '{{.Names}}' | grep -qx 'ubuntu-gnome'; then
        docker pull cannycomputing/dockerfile-ubuntu-gnome

        docker run -d \
          --name ubuntu-gnome \
          -p 10000:6901 \
          -e VNC_PW=12345678 \
          -e VNC_RESOLUTION=1280x800 \
          cannycomputing/dockerfile-ubuntu-gnome
      else
        docker start ubuntu-gnome || true
      fi

      # chờ novnc
      while ! nc -z localhost 10000; do
        sleep 1
      done

      # cài chrome
      docker exec ubuntu-gnome bash -lc "
        sudo apt update
        sudo apt install -y wget
        wget -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo apt install -y /tmp/chrome.deb
        rm -f /tmp/chrome.deb
      "

      # chạy cloudflare tunnel
      nohup cloudflared tunnel \
        --no-autoupdate \
        --url http://localhost:10000 \
        > /tmp/cloudflared.log 2>&1 &

      sleep 8

      URL=""

      for i in {1..20}; do
        URL=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1)
        if [ -n "$URL" ]; then break; fi
        sleep 1
      done

      if [ -n "$URL" ]; then
        echo "======================================"
        echo "🌍 LINK VPS:"
        echo "$URL"
        echo ""
        echo "🔑 Mật khẩu: 12345678"
        echo "======================================"
      else
        echo "❌ Không lấy được link cloudflare"
      fi

      elapsed=0
      while true; do
        echo "VPS running: $elapsed min"
        elapsed=$((elapsed+1))
        sleep 60
      done
    '';
  };

  idx.previews = {
    enable = true;
    previews = {
      novnc = {
        manager = "web";
        command = [
          "bash"
          "-lc"
          "socat TCP-LISTEN:$PORT,fork,reuseaddr TCP:127.0.0.1:10000"
        ];
      };
    };
  };

}
