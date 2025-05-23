#!/bin/bash

set -euo pipefail

# Parse arguments
CLEANUP_AFTER=true

for arg in "$@"; do
    case $arg in
        --no-cleanup)
            CLEANUP_AFTER=false
            ;;
        -h|--help)
            echo "Usage: $0 [--no-cleanup] [-h|--help]"
            echo "Test dotfiles setup using Cirrus CLI"
            echo ""
            echo "Options:"
            echo "  --no-cleanup     Don't cleanup artifacts after testing"
            echo "  -h, --help       Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Install Cirrus CLI if not available
if ! command -v cirrus &> /dev/null; then
    echo "Installing Cirrus CLI..."
    brew install cirruslabs/cli/cirrus
fi

# Check if .cirrus.yml exists
if [ ! -f ".cirrus.yml" ]; then
    echo "Error: .cirrus.yml not found. Please ensure you're in the dotfiles directory."
    exit 1
fi

echo "Running dotfiles tests..."

# Run tests with artifact collection
if cirrus run --artifacts-dir artifacts; then
    echo "✅ All tests passed!"
    
    # Show artifacts if they exist
    if [ -d "artifacts" ]; then
        echo "Artifacts collected:"
        find artifacts -type f -exec echo "  📄 {}" \;
    fi
    
    # Cleanup artifacts if requested
    if [ "$CLEANUP_AFTER" = true ] && [ -d "artifacts" ]; then
        echo "Cleaning up artifacts..."
        rm -rf artifacts
    fi
    
    echo "🎉 Testing completed successfully!"
else
    echo "❌ Tests failed. Check output above for details."
    exit 1
fi
