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
    pkgs.apt
    pkgs.systemd
  ];

  services.docker.enable = true;

  idx.workspace.onStart = {
    gnomegui = ''
      set -e

      echo "[✅] Starting GNOME GUI environment via Docker + noVNC..."

      # Cleanup (chỉ làm lần đầu)
      if [ ! -f /home/user/.cleanup_done ]; then
        rm -rf /home/user/.gradle/* /home/user/.emu/* || true
        find /home/user -mindepth 1 -maxdepth 1 ! -name 'idx-ubuntu22-gui' ! -name '.*' -exec rm -rf {} + || true
        touch /home/user/.cleanup_done
      fi

      # Tạo container nếu chưa có
      if ! docker ps -a --format '{{.Names}}' | grep -qx 'ubuntu-gnome-novnc'; then
        docker run --name ubuntu-gnome-novnc \
          --shm-size 1g -d \
          --cap-add=SYS_ADMIN \
          --restart unless-stopped \
          -p 8080:10000 \
          -e VNC_PASSWD=12345678 \
          -e PORT=10000 \
          -e SCREEN_WIDTH=1280 \
          -e SCREEN_HEIGHT=800 \
          -e SCREEN_DEPTH=24 \
          thuonghai2711/ubuntu-gnome-novnc:22.04 || (
            echo "⚠️ Không tìm thấy image ubuntu-gnome-novnc, đang tạo tạm từ ubuntu:22.04..."
            docker run --name ubuntu-gnome-novnc \
              -d --shm-size=1g --cap-add=SYS_ADMIN \
              -p 8080:10000 \
              ubuntu:22.04 sleep infinity
            docker exec ubuntu-gnome-novnc bash -lc '
              apt update &&
              DEBIAN_FRONTEND=noninteractive apt install -y gnome-session gdm3 tigervnc-standalone-server websockify novnc dbus-x11 pulseaudio wget sudo &&
              mkdir -p /root/.vnc &&
              echo 12345678 | vncpasswd -f > /root/.vnc/passwd &&
              chmod 600 /root/.vnc/passwd &&
              echo "vncserver -geometry 1280x800 -depth 24 -SecurityTypes None :1" > /usr/local/bin/startvnc &&
              chmod +x /usr/local/bin/startvnc
            '
          )
      else
        docker start ubuntu-gnome-novnc || true
      fi

      # Cài Chrome trong container
      docker exec ubuntu-gnome-novnc bash -lc '
        apt update -y &&
        apt install -y wget gnupg ca-certificates sudo &&
        wget -O /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb &&
        apt install -y /tmp/chrome.deb || apt -f install -y &&
        rm -f /tmp/chrome.deb
      '

      # Chạy GNOME + VNC + noVNC
      docker exec -d ubuntu-gnome-novnc bash -lc '
        export DISPLAY=:1
        dbus-launch --exit-with-session gnome-session &
        vncserver -geometry 1280x800 -depth 24 -SecurityTypes None :1
        websockify --web=/usr/share/novnc 10000 localhost:5901 &
      '

      # Chạy cloudflared (public tunnel)
      nohup cloudflared tunnel --no-autoupdate --url http://localhost:8080 > /tmp/cloudflared.log 2>&1 &

      sleep 10
      URL=$(grep -Eo "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1 || true)
      if [ -n "$URL" ]; then
        echo "========================================="
        echo " 🌍 GNOME GUI qua Cloudflared đã sẵn sàng:"
        echo "     $URL"
        echo "========================================="
      else
        echo "❌ Không tìm thấy URL tunnel, kiểm tra /tmp/cloudflared.log"
        tail -n 40 /tmp/cloudflared.log || true
      fi

      elapsed=0; while true; do echo "⏳ Đã chạy $elapsed phút"; ((elapsed++)); sleep 60; done
    '';
  };

  idx.previews = {
    enable = true;
    previews = {
      gnomegui = {
        manager = "web";
        command = [
          "bash" "-lc"
          "socat TCP-LISTEN:8080,fork,reuseaddr TCP:127.0.0.1:8080"
        ];
      };
    };
  };
}
