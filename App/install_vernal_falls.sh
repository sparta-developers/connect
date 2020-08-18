#!/usr/bin/env bash

set -o errexit

#  install_vernal_falls.sh
#  SpartaConnect
#
#  Created by Sparta Science on 5/29/20.
#  Copyright © 2020 Sparta Science. All rights reserved.

pwd=$(pwd)
cat > sparta_science.vernal_falls.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>KeepAlive</key>
    <dict>
    <key>PathState</key>
        <dict>
        <key>$pwd/vernal_falls_config.yml</key>
        <true/>
        </dict>
    </dict>
    <key>Label</key>
    <string>sparta_science.vernal_falls</string>
    <key>ProgramArguments</key>
    <array>
        <string>$pwd/vernal_falls/CURRENT/bin/vernal_falls</string>
        <string>foreground</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>SCAN_DIR</key>
        <string>$pwd/scan</string>
        <key>VF_CONFIG</key>
        <string>$pwd/vernal_falls_config.yml</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>$pwd/vernal_falls/CURRENT</string>
    <key>StandardOutPath</key>
    <string>$HOME/Library/Logs/com.spartascience.SpartaConnect/vernal_falls.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/Library/Logs/com.spartascience.SpartaConnect/vernal_falls.log</string>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
EOF

rm -rf vernal_falls
mkdir vernal_falls
cd vernal_falls
tar xf ../vernal_falls.tar.gz
ln -s . CURRENT
