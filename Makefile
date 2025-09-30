# WakaTerm NG Build System
# Cross-platform Makefile for building optimized binaries

# Configuration
PYTHON := python3
BINARY_NAME := wakaterm
BUILD_DIR := build
DIST_DIR := dist
BINARY_DIR := binaries

# Platform detection
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Linux)
    PLATFORM := linux
endif
ifeq ($(UNAME_S),Darwin)
    PLATFORM := macos
endif

ifeq ($(UNAME_M),x86_64)
    ARCH := x86_64
endif
ifeq ($(UNAME_M),arm64)
    ARCH := arm64
endif
ifeq ($(UNAME_M),aarch64)
    ARCH := arm64
endif

BINARY_SUFFIX := $(PLATFORM)-$(ARCH)

# Default target
.PHONY: all
all: build

# Display help
.PHONY: help
help:
	@echo "WakaTerm NG Build System"
	@echo ""
	@echo "Available targets:"
	@echo "  help          Show this help message"
	@echo "  install-deps  Install build dependencies"
	@echo "  build         Build optimized binary for current platform"
	@echo "  build-debug   Build debug binary (unoptimized)"
	@echo "  test          Build and test binary"
	@echo "  clean         Clean build artifacts"
	@echo "  install       Build and install binary to ~/.local/bin"
	@echo "  installer     Create universal installer script"
	@echo "  package       Create release package"
	@echo "  size          Show binary size comparison"
	@echo ""
	@echo "Current platform: $(PLATFORM)-$(ARCH)"

# Install build dependencies
.PHONY: install-deps
install-deps:
	@echo "📦 Installing build dependencies..."
	$(PYTHON) -m pip install --upgrade pip
	$(PYTHON) -m pip install cython>=3.0.0

# Build optimized binary
.PHONY: build
build:
	@echo "🚀 Building Cython-optimized binary for $(PLATFORM)-$(ARCH)..."
	$(PYTHON) build.py

# Build debug binary
.PHONY: build-debug
build-debug:
	@echo "🐛 Building debug binary for $(PLATFORM)-$(ARCH)..."
	$(PYTHON) build.py --no-optimize

# Test binary
.PHONY: test
test:
	@echo "🧪 Building and testing binary..."
	$(PYTHON) build.py --test

# Clean build artifacts
.PHONY: clean
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf $(BUILD_DIR) $(DIST_DIR)
	$(PYTHON) build.py --clean

# Install binary to local bin
.PHONY: install
install: build
	@echo "📥 Installing wakaterm binaries..."
	@mkdir -p ~/.local/bin
	@cp $(BINARY_DIR)/$(BINARY_NAME)-$(BINARY_SUFFIX) ~/.local/bin/$(BINARY_NAME) 2>/dev/null || \
		echo "⚠️  wakaterm binary not found"
	@cp $(BINARY_DIR)/wakatermctl-$(BINARY_SUFFIX) ~/.local/bin/wakatermctl 2>/dev/null || \
		echo "⚠️  wakatermctl binary not found"
	@cp -r $(BINARY_DIR)/wakaterm-dist ~/.local/share/ 2>/dev/null || true
	@cp -r $(BINARY_DIR)/wakatermctl-dist ~/.local/share/ 2>/dev/null || true
	@chmod +x ~/.local/bin/$(BINARY_NAME) 2>/dev/null || true
	@chmod +x ~/.local/bin/wakatermctl 2>/dev/null || true
	@echo "✅ Binaries installed to ~/.local/bin/"
	@echo "💡 Make sure ~/.local/bin is in your PATH"

# Create universal installer
.PHONY: installer
installer:
	@echo "🌍 Creating universal installer..."
	$(PYTHON) build.py --installer

# Create release package
.PHONY: package
package: clean build installer
	@echo "📦 Creating release package..."
	@mkdir -p release
	@cp $(BINARY_DIR)/$(BINARY_NAME)-$(BINARY_SUFFIX) release/
	@cp install.sh release/
	@cp README.md release/
	@cp LICENSE release/
	@echo "✅ Release package created in ./release/"

# Show binary size information
.PHONY: size
size:
	@echo "📊 Binary size information:"
	@echo "Python script sizes:"
	@ls -lh wakaterm.py ignore_filter.py wakatermctl | awk '{print "  " $$9 ": " $$5}'
	@if [ -d $(BINARY_DIR) ]; then \
		echo "Compiled binary sizes:"; \
		ls -lh $(BINARY_DIR)/ | tail -n +2 | grep -v dist | awk '{print "  " $$9 ": " $$5}'; \
		echo "Distribution directory sizes:"; \
		du -sh $(BINARY_DIR)/*-dist/ 2>/dev/null | sed 's/^/  /' || true; \
	fi

# Development helpers
.PHONY: dev-setup
dev-setup: install-deps
	@echo "🔧 Setting up development environment..."
	@$(PYTHON) -c "import sys; print(f'Python: {sys.version}')"
	@$(PYTHON) -c "import platform; print(f'Platform: {platform.system()}-{platform.machine()}')"

.PHONY: benchmark
benchmark:
	@echo "⚡ Running performance benchmark..."
	@echo "Python wakaterm:"
	@time $(PYTHON) wakaterm.py --help >/dev/null 2>&1 || true
	@echo "Binary wakaterm:"
	@time $(BINARY_DIR)/$(BINARY_NAME)-$(BINARY_SUFFIX) --help >/dev/null 2>&1 || echo "Binary not found"
	@echo "Python wakatermctl:"
	@time $(PYTHON) wakatermctl --help >/dev/null 2>&1 || true  
	@echo "Binary wakatermctl:"
	@time $(BINARY_DIR)/wakatermctl-$(BINARY_SUFFIX) --help >/dev/null 2>&1 || echo "Binary not found"

# Validation targets
.PHONY: validate
validate:
	@echo "✅ Validating Python code..."
	@$(PYTHON) -m py_compile wakaterm.py
	@$(PYTHON) -m py_compile ignore_filter.py
	@echo "✅ Python code validation passed"