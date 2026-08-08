#!/bin/bash

if [ "$(uname)" != "Darwin" ]; then
    echo "macOSではありません"
    exit 1
fi

# ====================
#
# Base
#
# ====================

# Disable auto-capitalization
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# ====================
#
# Dock
#
# ====================

# Disable animation at application launch
defaults write com.apple.dock launchanim -bool false

## Dockからすべてのアプリを消す
defaults write com.apple.dock persistent-apps -array

## Dockのサイズ
defaults write com.apple.dock "tilesize" -int "60"

## 最近起動したアプリを非表示
defaults write com.apple.dock "show-recents" -bool "false"

# “自動的に非表示”をオン
defaults write com.apple.dock autohide -bool true

# Dockを右に
defaults write com.apple.dock orientation -string "right"

# ====================
#
# Screenshot
#
# ====================

## 画像の影を無効化
defaults write com.apple.screencapture "disable-shadow" -bool "true"

## 保存場所
if [[ ! -d "$HOME/Pictures/Screenshots" ]]; then
    mkdir -p "$HOME/Pictures/Screenshots"
fi
defaults write com.apple.screencapture "location" -string "$HOME/Pictures/Screenshots"

## 撮影時のサムネイル表示
defaults write com.apple.screencapture "show-thumbnail" -bool "false"

## 保存形式
defaults write com.apple.screencapture "type" -string "jpg"

# ====================
#
# Finder
#
# ====================

# Disable animation
defaults write com.apple.finder DisableAllAnimations -bool true

# Show hidden files by default
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show files with all extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Display the status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Display the path bar
defaults write com.apple.finder ShowPathbar -bool true

# ====================
#
# SystemUIServer
#
# ====================

# Display date, day, and time in the menu bar
defaults write com.apple.menuextra.clock DateFormat -string 'EEE d MMM HH:mm'

# ====================
#
# Trackpad
#
# ====================

## タップでクリック
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool "true"
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool "true"
defaults -currentHost write -g com.apple.mouse.tapBehavior -bool "true"

## 軌跡の速さ
defaults write -g com.apple.trackpad.scaling 3

# ====================
#
# Keyboard
#
# ====================

## キーのリピート速度
defaults write NSGlobalDomain KeyRepeat -int 2

## キーのリピート認識時間
defaults write NSGlobalDomain InitialKeyRepeat -int 12

## フルキーボードアクセスを有効化
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

## 本体キーボードのCapsLockキーの動作をControlにリマップ
keyboard_id="$(ioreg -c AppleEmbeddedKeyboard -r | grep -Eiw "VendorID|ProductID" | awk '{ print $4 }' | paste -s -d'-\n' -)-0"
defaults -currentHost write -g com.apple.keyboard.modifiermapping."${keyboard_id}" -array-add "
<dict>
  <key>HIDKeyboardModifierMappingDst</key>\
  <integer>30064771300</integer>\
  <key>HIDKeyboardModifierMappingSrc</key>\
  <integer>30064771129</integer>\
</dict>
"

for app in "Dock" \
    "Finder" \
    "SystemUIServer"; do
    killall "${app}" &>/dev/null
done
