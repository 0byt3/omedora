Implementation of Omarchy on Fedora. Referred to as 'Nier' or 'nier-desktop'.

Install on Fedora as the desktop user (the script uses sudo for repository and package changes):

```bash
bash install.sh
```

This enables the `fedora-workstation` repository and the COPR projects `byte0/hyprland`, `byte0/quickshell`, and `byte0/nier`, installs the `nier-desktop` package, then runs `nier apply --system-wide` and `nier apply`.
