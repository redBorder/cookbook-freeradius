Name:     cookbook-rb-freeradius
Version:  %{__version}
Release:  %{__release}%{?dist}

License:  GNU AGPLv3
URL:  https://github.com/redBorder/cookbook-rb-freeradius
Source0: %{name}-%{version}.tar.gz

BuildRequires: maven java-devel

Summary: freeradius cookbook to install and configure it in redborder environments
Requires: java

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/var/chef/cookbooks/rb-freeradius
mkdir -p %{buildroot}/usr/lib64/rb-freeradius

cp -f -r  resources/* %{buildroot}/var/chef/cookbooks/rb-freeradius/
chmod -R 0755 %{buildroot}/var/chef/cookbooks/rb-freeradius
install -D -m 0644 README.md %{buildroot}/var/chef/cookbooks/rb-freeradius/README.md

%pre

%post
case "$1" in
  1)
    # This is an initial install.
    :
  ;;
  2)
    # This is an upgrade.
    su - -s /bin/bash -c 'source /etc/profile && rvm gemset use default && env knife cookbook upload rbfreeradius'
  ;;
esac

systemctl daemon-reload
%files
%defattr(0755,root,root)
/var/chef/cookbooks/rb-freeradius
%defattr(0644,root,root)
/var/chef/cookbooks/rb-freeradius/README.md

%doc

%changelog
* Wed Dec 29 2021 Vicente Mesa <vimesa@redborder.com>- 0.0.1
- first spec version
