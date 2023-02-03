Name:     cookbook-freeradius
Version:  %{__version}
Release:  %{__release}%{?dist}

License:  GNU AGPLv3
URL:  https://github.com/redBorder/cookbook-freeradius
Source0: %{name}-%{version}.tar.gz


Summary: freeradius cookbook to install and configure it in redborder environments


%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/var/chef/cookbooks/freeradius
mkdir -p %{buildroot}/usr/lib64/freeradius

cp -f -r  resources/* %{buildroot}/var/chef/cookbooks/freeradius/
chmod -R 0755 %{buildroot}/var/chef/cookbooks/freeradius
install -D -m 0644 README.md %{buildroot}/var/chef/cookbooks/freeradius/README.md

%pre

%post
case "$1" in
  1)
    # This is an initial install.
    :
  ;;
  2)
    # This is an upgrade.
    su - -s /bin/bash -c 'source /etc/profile && rvm gemset use default && env knife cookbook upload freeradius'
  ;;
esac

systemctl daemon-reload
%files
%defattr(0755,root,root)
/var/chef/cookbooks/freeradius
%defattr(0644,root,root)
/var/chef/cookbooks/freeradius/README.md

%doc

%changelog
* Fri Feb 3 2023 Luis Blanco  <ljblanco@redborder.com> 0.0.2
- Integrate freeradius in proxy
* Wed Dec 29 2021 Vicente Mesa <vimesa@redborder.com>- 0.0.1
- first spec version
