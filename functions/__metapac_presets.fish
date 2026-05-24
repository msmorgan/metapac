function __metapac_presets --description "Archinstall desktop preset data"
    if not set -q argv[1]
        echo awesome
        echo bspwm
        echo budgie
        echo cinnamon
        echo cosmic
        echo cutefish
        echo deepin
        echo enlightenment
        echo gnome
        echo hyprland
        echo i3
        echo labwc
        echo lxqt
        echo mate
        echo niri
        echo plasma
        echo qtile
        echo river
        echo sway
        echo xfce4
        echo xmonad
        return
    end

    switch $argv[1]
        case awesome
            echo awesome alacritty xorg-xrandr xterm feh slock terminus-font gnu-free-fonts ttf-liberation xsel | string split ' '
        case bspwm
            echo bspwm sxhkd dmenu xdo rxvt-unicode | string split ' '
        case budgie
            echo materia-gtk-theme budgie mate-terminal nemo papirus-icon-theme | string split ' '
        case cinnamon
            echo cinnamon system-config-printer gnome-keyring gnome-terminal engrampa gnome-screenshot gvfs-smb xed xdg-user-dirs-gtk | string split ' '
        case cosmic
            echo cosmic xdg-user-dirs | string split ' '
        case cutefish
            echo cutefish noto-fonts | string split ' '
        case deepin
            echo deepin deepin-terminal deepin-editor | string split ' '
        case enlightenment
            echo enlightenment terminology | string split ' '
        case gnome
            echo gnome gnome-tweaks | string split ' '
        case hyprland
            echo hyprland dunst kitty uwsm dolphin wofi xdg-desktop-portal-hyprland qt5-wayland qt6-wayland polkit-kde-agent grim slurp | string split ' '
        case i3
            echo i3-wm i3lock i3status i3blocks xss-lock xterm lightdm-gtk-greeter lightdm dmenu | string split ' '
        case labwc
            echo alacritty labwc | string split ' '
        case lxqt
            echo lxqt breeze-icons oxygen-icons xdg-utils ttf-freefont l3afpad slock | string split ' '
        case mate
            echo mate mate-extra | string split ' '
        case niri
            echo niri alacritty fuzzel mako xorg-xwayland waybar swaybg swayidle swaylock xdg-desktop-portal-gnome | string split ' '
        case plasma
            set variant recommended
            if set -q argv[2]
                set variant $argv[2]
            end
            switch $variant
                case recommended
                    echo plasma-meta | string split ' '
                case extensive
                    echo plasma | string split ' '
                case minimal
                    echo plasma-desktop | string split ' '
                case '*'
                    echo "metapac: unknown plasma variant: $variant (use recommended, extensive, or minimal)" >&2
                    return 1
            end
        case qtile
            echo qtile alacritty | string split ' '
        case river
            echo foot xdg-desktop-portal-wlr river | string split ' '
        case sway
            echo sway swaybg swaylock swayidle waybar wmenu brightnessctl grim slurp pavucontrol foot xorg-xwayland | string split ' '
        case xfce4
            echo xfce4 xfce4-goodies pavucontrol gvfs xarchiver | string split ' '
        case xmonad
            echo xmonad xmonad-contrib xmonad-extras xterm dmenu | string split ' '
        case '*'
            echo "metapac: unknown preset: $argv[1]" >&2
            return 1
    end
end
