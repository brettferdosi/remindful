.PHONY: app package clean

MAKEFILE_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# puts the app in $(MAKEFILE_DIR)/build/Build/Products/Release/name.app
app:
	pushd "$(MAKEFILE_DIR)"; xcodebuild -project remindful.xcodeproj -scheme remindful -configuration Release -derivedDataPath build; popd

# first argument is the path of the .app file, second argument is installation
# directory for the app when the .pkg is run, third argument is the output
# location for the .pkg file
package:
	productbuild --component "$(MAKEFILE_DIR)/build/Build/Products/Release/remindful.app" "/Applications" "$(MAKEFILE_DIR)/build/RemindfulInstaller.pkg"

clean:
	rm -rf "$(MAKEFILE_DIR)/build"
