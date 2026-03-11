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
    android = ''
      set -e

      mkdir -p ~/vps
      cd ~/vps

      # cleanup 1 lần
      if [ ! -f /home/user/.cleanup_done ]; then
        rm -rf /home/user/.gradle/* /home/user/.emu/* || true
        touch /home/user/.cleanup_done
      fi

      # pull android container
      if ! docker ps -a --format '{{.Names}}' | grep -qx 'android'; then
        docker pull budtmo/docker-android:emulator_14.0

        docker run -d \
          --name android \
          --device /dev/kvm \
          -p 6080:6080 \
          -p 5554:5554 \
          -p 5555:5555 \
          -e DEVICE="Samsung Galaxy S10" \
          budtmo/docker-android:emulator_14.0

      else
        docker start android || true
      fi

      # chờ web vnc
      while ! nc -z localhost 6080; do
        sleep 2
      done

      # chạy cloudflare tunnel
      nohup cloudflared tunnel \
        --no-autoupdate \
        --url http://localhost:6080 \
        > /tmp/cloudflared.log 2>&1 &

      sleep 8

      URL=""

      for i in {1..20}; do
        URL=$(grep -o "https://[a-z0-9.-]*trycloudflare.com" /tmp/cloudflared.log | head -n1)
        if [ -n "$URL" ]; then break; fi
        sleep 1
      done

      if [ -n "$URL" ]; then
        echo "================================="
        echo "📱 Android Emulator đang chạy:"
        echo "$URL"
        echo "================================="
      else
        echo "❌ Không lấy được link Cloudflare"
      fi

      elapsed=0
      while true; do
        echo "Android running: $elapsed min"
        elapsed=$((elapsed+1))
        sleep 60
      done
    '';
  };

  idx.previews = {
    enable = true;
    previews = {
      android = {
        manager = "web";
        command = [
          "bash"
          "-lc"
          "socat TCP-LISTEN:$PORT,fork,reuseaddr TCP:127.0.0.1:6080"
        ];
      };
    };
  };

}
