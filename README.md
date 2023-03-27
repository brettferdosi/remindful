<img src="https://raw.githubusercontent.com/brettferdosi/remindful/doc/logo.png" width="150px">

# remindful

`remindful` is a macOS status bar app that displays firm but gentle periodic reminders.
It integrates well with the OS and works over fullscreen apps and across spaces.
It's useful for the Pomodoro Technique and reminding you to get up from your desk once in a while.

Left click the menu bar bar icon to toggle reminders, and right click it to access the `remindful` menu.
The default reminder interval is 30 minutes.

<img src="https://raw.githubusercontent.com/brettferdosi/remindful/doc/demo.gif">

`remindful` has been tested on macOS 13 Ventura but may also work on other versions. 

## Installing remindful

**Install option 1: homebrew**

Run `brew install --cask --no-quarantine brettferdosi/tap/remindful`. `remindful.app` will be
installed in `/Applications`.

**Install option 2: run the installer (easiest for non-technical users)**

Download the [most recent installer](https://github.com/brettferdosi/remindful/releases/latest/download/RemindfulInstaller.pkg) (`RemindfulInstaller.pkg`) from the [releases page](https://github.com/brettferdosi/remindful/releases).
To run the installer, control-click its icon, click *Open*, then click *Open* again.
See the [Apple support page](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac) if the process for running apps from unidentified developers has changed.
It will install `remindful.app` in `/Applications`.
If there is already a version of `remindful.app` on your system, the installer will detect and overwrite it.

**Install option 3: build from source**

Clone this git repository and run `make` in it. `remindful.app` will be placed into `build/Build/Products/Release`.

**Optional: open at login**

Automatically open `remindful` at login by adding it to the list in System Settings > General > Login Items.
See the [Apple support page](https://support.apple.com/guide/mac-help/open-items-automatically-when-you-log-in-mh15189/mac) if the location of the list has changed.
