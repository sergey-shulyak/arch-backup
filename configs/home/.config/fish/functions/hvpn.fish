function hvpn
    if test (count $argv) -ne 1
        echo "Usage: hvpn connect|disconnect"
        return 1
    end

    set action $argv[1]
    set config ~/Documents/home.ovpn

    if test ! -f $config
        echo "Error: Profile not found at $config"
        return 1
    end

    switch $action
        case connect
            # Check if already connected
            if pgrep -f "openvpn.*home.ovpn" > /dev/null
                notify-send "Home VPN" "🔗 Already connected"
                return 0
            end

            # Start OpenVPN in background
            sudo openvpn --config $config --daemon --log /tmp/hvpn.log

            # Give it a moment to start
            sleep 2

            # Check if it started successfully
            if pgrep -f "openvpn.*home.ovpn" > /dev/null
                notify-send "Home VPN" "🔗 Connected" -u low
                return 0
            else
                notify-send "Home VPN" "❌ Failed to connect" -u critical
                return 1
            end

        case disconnect
            # Check if connected
            if not pgrep -f "openvpn.*home.ovpn" > /dev/null
                notify-send "Home VPN" "🔓 Not connected"
                return 0
            end

            # Kill OpenVPN process
            sudo pkill -f "openvpn.*home.ovpn"

            sleep 1

            # Verify it stopped
            if not pgrep -f "openvpn.*home.ovpn" > /dev/null
                notify-send "Home VPN" "🔓 Disconnected" -u low
                return 0
            else
                notify-send "Home VPN" "❌ Failed to disconnect" -u critical
                return 1
            end

        case '*'
            notify-send "Home VPN" "❌ Unknown action: $action. Use 'connect' or 'disconnect'"
            return 1
    end
end
