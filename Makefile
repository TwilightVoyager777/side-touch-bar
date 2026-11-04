.PHONY: build run install uninstall test package clean

build:
	scripts/build-app.sh release

run:
	scripts/build-app.sh debug
	open build/SideTouchBar.app

install:
	scripts/install.sh

uninstall:
	scripts/uninstall.sh

test:
	scripts/test.sh

package:
	scripts/package.sh

clean:
	rm -rf .build build dist
