
NAME = vagrant-vbguest-windows
VERSION = $(shell [ ! -z $$TRAVIS_TAG ] && echo $$TRAVIS_TAG || cat ./version.txt)

.PHONY: clean install test

all: clean test build install

build:
	./bin/setup
	bundle exec rake build

clean:
	rm -f ./pkg/${NAME}-*.gem

install:
	vagrant plugin install ./pkg/${NAME}-${VERSION}.gem

test:
	bundle exec rake
