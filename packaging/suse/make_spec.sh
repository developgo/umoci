#!/bin/bash

if [ -z "$1" ]; then
  cat <<EOF
usage:
  ./make_spec.sh PACKAGE
EOF
  exit 1
fi

cd $(dirname $0)

YEAR=$(date +%Y)
VERSION=$(cat ../../VERSION)
COMMIT_UNIX_TIME=$(git show -s --format=%ct)
VERSION="${VERSION%+*}+$(date -d @$COMMIT_UNIX_TIME +%Y%m%d).$(git rev-parse --short HEAD)"
NAME=$1

cat <<EOF > ${NAME}.spec
#
# spec file for package $NAME
#
# Copyright (c) $YEAR SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#
# nodebuginfo

# Handle all Go arches.
%{!?go_arches: %global go_arches %ix86 x86_64 aarch64 ppc64le}

# Remove stripping of Go binaries.
%define __arch_install_post export NO_BRP_STRIP_DEBUG=true

# Project name when using go tooling.
%define project github.com/openSUSE/umoci

Name:           $NAME
Version:        $VERSION
Release:        0
Summary:        Open Container Image manipulation tool
License:        Apache-2.0
Group:          System/Management
Url:            https://github.com/openSUSE/umoci
Source:         master.tar.gz
%ifarch %{go_arches}
BuildRequires:  go >= 1.6
BuildRequires:  go-go-md2man
%else
BuildRequires:  gcc6-go >= 6.1
%endif
BuildRequires:  fdupes
BuildRoot:      %{_tmppath}/%{name}-%{raw_version}-build
%if 0%{?is_opensuse}
ExcludeArch:    s390x
%endif

%description
umoci modifies Open Container images.

umoci is a manipulation tool for OCI images. In particular, it is an
alternative to oci-image-tools provided by the OCI.

%prep
%setup -q -n $NAME-master

%build

# We can't use symlinks here because go-list gets confused by symlinks, so we
# have to copy the source to \$HOME/go and then use that as the GOPATH.
export GOPATH=\$HOME/go
mkdir -pv \$HOME/go/src/%{project}
rm -rf \$HOME/go/src/%{project}/*
cp -avr * \$HOME/go/src/%{project}

export VERSION="\$(cat ./VERSION)"
if [ "\$VERSION" != "%{version}" ]; then
  VERSION="%{version}_suse"
fi

# Build the binary.
make VERSION="\$VERSION" umoci

# Build the docs if we have go-md2man.
%ifarch %{go_arches}
make doc
%endif

%install
# Install the binary.
install -D -m 0755 %{name} "%{buildroot}/%{_bindir}/%{name}"

# Install all of the docs.
%ifarch %{go_arches}
for file in man/*.1; do
  install -D -m 0644 \$file "%{buildroot}/%{_mandir}/man1/\$(basename \$file)"
done
%endif

%fdupes %{buildroot}/%{_prefix}

%check
export GOPATH=\$HOME/go
hack/test-unit.sh

%files
%defattr(-,root,root)
%doc COPYING README.md man/*.md
%{_bindir}/%{name}
%ifarch %{go_arches}
%{_mandir}/man1/umoci*
%endif

%changelog
EOF
