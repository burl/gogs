LDFLAGS += -X "github.com/gogits/gogs/modules/setting.BuildTime=$(shell date -u '+%Y-%m-%d %I:%M:%S %Z')"
LDFLAGS += -X "github.com/gogits/gogs/modules/setting.BuildGitHash=$(shell git rev-parse HEAD)"

DATA_FILES := $(shell find conf | sed 's/ /\\ /g')
LESS_FILES := $(wildcard public/less/gogs.less public/less/_*.less)
GENERATED  := modules/bindata/bindata.go public/css/gogs.css
MAKEFILE   := $(lastword $(MAKEFILE_LIST))
GOX_URL    := github.com/mitchellh/gox
REL_OSES   := darwin linux freebsd
REL_ARCHES := amd64

TAGS = ""
BUILD_FLAGS = "-v"

RELEASE_ROOT = "release"
RELEASE_GOGS = "release/gogs"
NOW = $(shell date -u '+%Y%m%d%I%M%S')
GOVET = go tool vet -composites=false -methods=false -structtags=false
THE_GOGS = gogs
THE_ZIP = gogs.$(NOW).zip

.PHONY: build pack release bindata clean cross-release

.IGNORE: public/css/gogs.css

all: build

check: test

dist: release

govet:
	$(GOVET) gogs.go
	$(GOVET) models modules routers

build: $(GENERATED)
	go install $(BUILD_FLAGS) -ldflags '$(LDFLAGS)' -tags '$(TAGS)'
	cp '$(GOPATH)/bin/gogs' .

cross-build: $(GENERATED)
	@if ! which gox >/dev/null 2>&1; then \
		echo "installing gox ..."; \
		echo "go get -v $(GOX_URL)"; \
		go get -v $(GOX_URL); \
	fi
	gox -output=$(RELEASE_ROOT)/{{.OS}}-{{.Arch}}/{{.Dir}} \
	  -os="$(REL_OSES)" -arch="$(REL_ARCHES)"

build-dev: $(GENERATED) govet
	go install $(BUILD_FLAGS) -tags '$(TAGS)'
	cp '$(GOPATH)/bin/gogs' .

build-dev-race: $(GENERATED) govet
	go install $(BUILD_FLAGS) -race -tags '$(TAGS)'
	cp '$(GOPATH)/bin/gogs' .

pack:
	rm -rf $(RELEASE_GOGS)
	mkdir -p $(RELEASE_GOGS)
	cp -r $(THE_GOGS) LICENSE README.md README_ZH.md templates public scripts $(RELEASE_GOGS)
	rm -rf $(RELEASE_GOGS)/public/config.codekit $(RELEASE_GOGS)/public/less
	cd $(RELEASE_ROOT) && zip -r $(THE_ZIP) "gogs"

release: build pack

cross-release: cross-build
	for arch in $(REL_ARCHES); do \
		for os in $(REL_OSES); do \
			$(MAKE) -f $(MAKEFILE) pack NOW=$(NOW) THE_ZIP=gogs-$$os-$$arch-$(NOW).zip THE_GOGS=$(RELEASE_ROOT)/$$os-$$arch/gogs; \
		done \
	done

bindata: modules/bindata/bindata.go

modules/bindata/bindata.go: $(DATA_FILES)
	go-bindata -o=$@ -ignore="\\.DS_Store|README.md|TRANSLATORS" -pkg=bindata conf/...

less: public/css/gogs.css

public/css/gogs.css: $(LESS_FILES)
	lessc $< $@

clean:
	go clean -i ./...

clean-mac: clean
	find . -name ".DS_Store" -print0 | xargs -0 rm

test:
	go test -cover -race ./...

fixme:
	grep -rnw "FIXME" routers models modules

todo:
	grep -rnw "TODO" routers models modules
