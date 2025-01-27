#!/bin/bash

#==============================================================================
# Docker Package Installer
#==============================================================================
# Author: Norbert Mooser
# Date: 2025-01-27
#
# Description:
#   This script automates the installation of Docker-related packages specified
#   in a docker_packages.yaml file. It checks for package availability, verifies
#   existing installations, and installs missing packages.
#
# Requirements:
#   - yq (YAML parser)
#   - sudo privileges
#   - docker_packages.yaml file in the current directory
#
# Usage:
#   ./install_docker_packages.sh [--nocheck] [--file path/to/any-packages.yaml]
#
# Options:
#   --nocheck    Skip package availability verification
#   --file       Specify a different YAML file
#
# Example docker_packages.yaml format:
#   packages:
#     - docker-ce
#     - docker-compose
#==============================================================================

# Exit on any error
set -e

# Help function
show_help() {
    cat << EOF
Docker Package Installer
Usage: $0 [OPTIONS]

Options:
    -h, --help, ?     Show this help message
    --nocheck         Skip package availability verification
    --file PATH       Specify a custom YAML file (default: docker_packages.yaml)

Example YAML format:
    packages:
        - docker-ce
        - docker-compose

The script will:
1. Check for package availability in apt repositories
2. Verify which packages are already installed
3. Install missing packages
4. Show installation status for each package

Requirements:
    - yq (YAML parser)
    - sudo privileges
    - Valid YAML file with package list
EOF
    exit 0
}

# Check for help flag immediately
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]] || [[ "$1" == "?" ]]; then
    show_help
fi

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Default yaml file location and name
YAML_FILE="$SCRIPT_DIR/docker_packages.yaml"

# Check if docker_packages.yaml exists in the script directory
if [ ! -f "$SCRIPT_DIR/docker_packages.yaml" ]; then
    echo "Error: docker_packages.yaml not found in script directory ($SCRIPT_DIR)"
    exit 1
fi

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "yq is not installed. Please install yq first."
    echo "You can install it using: snap install yq"
    exit 1
fi

echo "yq is installed, proceeding..."

# Check if sudo requires password
if sudo -n true 2>/dev/null; then
    echo "Sudo access available without password"
else
    echo "Sudo requires password. Please run with sudo privileges"
    exit 1
fi

# Parse remaining command line arguments
SKIP_CHECK=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --nocheck)
            SKIP_CHECK=true
            shift
            ;;
        --file)
            if [ -n "$2" ]; then
                YAML_FILE="$2"
                shift 2
            else
                echo "Error: --file requires a path argument"
                echo "Example: --file /path/to/my-packages.yaml"
                exit 1
            fi
            ;;
        *)
            echo "Unknown parameter: $1"
            echo "Use -h, --help, or ? for usage information"
            exit 1
            ;;
    esac
done

# Check if specified YAML file exists
if [ ! -f "$YAML_FILE" ]; then
    echo "Error: YAML file not found at: $YAML_FILE"
    exit 1
fi

# Read and print packages from docker_packages.yaml
echo "Reading packages from docker_packages.yaml:"
packages=$(yq eval '.packages[]' "$YAML_FILE")

# Verify package availability
if [ "$SKIP_CHECK" = false ]; then
    echo "Verifying package availability..."
    unavailable_packages=()
    while IFS= read -r package; do
        echo "Checking package: $package"
        if ! apt-cache search "^$package$" >/dev/null 2>&1; then
            unavailable_packages+=("$package")
        fi
    done <<< "$packages"

    if [ ${#unavailable_packages[@]} -ne 0 ]; then
        echo "The following packages are not available in apt repositories:"
        printf '%s\n' "${unavailable_packages[@]}"
        exit 1
    fi

    echo "All packages are available in apt repositories"
else
    echo "Skipping package availability check..."
fi

# Check which packages are already installed
echo -e "\n📦 Checking for already installed packages..."
packages_to_install=()
while IFS= read -r package; do
    if ! dpkg -l | grep -q "^ii\s*$package\s"; then
        echo "  ➜ Package not installed: $package"
        packages_to_install+=("$package")
    fi
done <<< "$packages"

if [ ${#packages_to_install[@]} -eq 0 ]; then
    echo -e "\n✨ All packages are already installed. Nothing to do.\n"
    exit 0
fi

echo -e "\n📋 Packages to be installed:"
printf '  • %s\n' "${packages_to_install[@]}"

# Install missing packages
echo -e "\n🚀 Starting installation...\n"
for package in "${packages_to_install[@]}"; do
    echo "  ⏳ Installing: $package"
    if sudo apt-get install -y "$package" >/dev/null 2>&1; then
        echo "  ✅ Successfully installed $package"
    else
        echo "  ❌ Failed to install $package"
        exit 1
    fi
    echo ""
done

echo -e "✨ All packages have been installed successfully\n"


