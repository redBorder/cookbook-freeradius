Name:     cookbook-rb-nmsp
Version:  %{__version}
Release:  %{__release}%{?dist}

License:  GNU AGPLv3
URL:  https://github.com/redBorder/cookbook-rb-nmsp
Source0: %{name}-%{version}.tar.gz

BuildRequires: maven java-devel

Summary: nmsp cookbook to install and configure it in redborder environments
Requires: java

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/var/chef/cookbooks/rb-nmsp
mkdir -p %{buildroot}/usr/lib64/rb-nmsp

cp -f -r  resources/* %{buildroot}/var/chef/cookbooks/rb-nmsp/
chmod -R 0755 %{buildroot}/var/chef/cookbooks/rb-nmsp
install -D -m 0644 README.md %{buildroot}/var/chef/cookbooks/rb-nmsp/README.md

%pre

%post
case "$1" in
  1)
    # This is an initial install.
    :
  ;;
  2)
    # This is an upgrade.
    su - -s /bin/bash -c 'source /etc/profile && rvm gemset use default && env knife cookbook upload rbnmsp'
  ;;
esac

systemctl daemon-reload
%files
%defattr(0755,root,root)
/var/chef/cookbooks/rb-nmsp
%defattr(0644,root,root)
/var/chef/cookbooks/rb-nmsp/README.md

%doc

%changelog
* Fri Dec 15 2021 Eduardo Reyes <eareyes@redborder.com>- 0.0.1
- first spec version
