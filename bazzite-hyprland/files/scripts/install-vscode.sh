#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing Visual Studio Code (Bluefin / Aurora pattern) ==="
# Import Microsoft RPM GPG key
rpm --import https://packages.microsoft.com/keys/microsoft.asc

# Ensure /etc/yum.repos.d/vscode.repo exists
if [ ! -f /etc/yum.repos.d/vscode.repo ]; then
  cat >/etc/yum.repos.d/vscode.repo <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=0
autorefresh=1
type=rpm-md
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
fi

# Install code with temporary repo enablement
dnf -y --setopt=install_weak_deps=False install --enablerepo=code code || dnf5 -y --setopt=install_weak_deps=False install --enablerepo=code code

# Guarantee vscode.repo remains disabled on the finished image
sed -i "s/enabled=.*/enabled=0/g" /etc/yum.repos.d/vscode.repo

echo "Visual Studio Code successfully installed."
