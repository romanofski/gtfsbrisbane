# https://fedoraproject.org/wiki/Packaging:Haskell

%global pkg_name gtfsschedule

%bcond_with tests

Name:           %{pkg_name}
Version:        0.4.0.0
Release:        1.20161204%{?dist}
Summary:        Be on time for your next public transport service

License:        GPLv3+
Url:            https://hackage.haskell.org/package/%{name}
Source0:        https://hackage.haskell.org/package/%{name}-%{version}/%{name}-%{version}.tar.gz

BuildRequires:  ghc-Cabal-devel
BuildRequires:  ghc-rpm-macros
# Begin cabal-rpm deps:
BuildRequires:  chrpath
BuildRequires:  ghc-bytestring-devel
BuildRequires:  ghc-cassava-devel
BuildRequires:  ghc-conduit-devel
BuildRequires:  ghc-conduit-extra-devel
BuildRequires:  ghc-containers-devel
BuildRequires:  ghc-directory-devel
BuildRequires:  ghc-esqueleto-devel
BuildRequires:  ghc-http-conduit-devel
BuildRequires:  ghc-http-types-devel
BuildRequires:  ghc-monad-logger-devel
BuildRequires:  ghc-mtl-devel
BuildRequires:  ghc-old-locale-devel
BuildRequires:  ghc-optparse-applicative-devel
BuildRequires:  ghc-persistent-devel
BuildRequires:  ghc-persistent-sqlite-devel
BuildRequires:  ghc-persistent-template-devel
BuildRequires:  ghc-protocol-buffers-devel
BuildRequires:  ghc-resourcet-devel
BuildRequires:  ghc-system-filepath-devel
BuildRequires:  ghc-temporary-devel
BuildRequires:  ghc-text-devel
BuildRequires:  ghc-time-devel
BuildRequires:  ghc-transformers-devel
BuildRequires:  ghc-utf8-string-devel
BuildRequires:  ghc-xdg-basedir-devel
BuildRequires:  ghc-zip-archive-devel
%if %{with tests}
BuildRequires:  ghc-lifted-base-devel
BuildRequires:  ghc-network-devel
BuildRequires:  ghc-streaming-commons-devel
BuildRequires:  ghc-tasty-devel
BuildRequires:  ghc-tasty-hunit-devel
BuildRequires:  ghc-transformers-base-devel
%endif
# End cabal-rpm deps

%description
Please see README.md.


%package -n ghc-%{name}
Summary:        Haskell %{name} library

%description -n ghc-%{name}
This package provides the Haskell %{name} shared library.


%package -n ghc-%{name}-devel
Summary:        Haskell %{name} library development files
Provides:       ghc-%{name}-static = %{version}-%{release}
Requires:       ghc-compiler = %{ghc_version}
Requires(post): ghc-compiler = %{ghc_version}
Requires(postun): ghc-compiler = %{ghc_version}
Requires:       ghc-%{name}%{?_isa} = %{version}-%{release}

%description -n ghc-%{name}-devel
This package provides the Haskell %{name} library development files.


%prep
%setup -q


%build
%ghc_lib_build


%install
%ghc_lib_install

%ghc_fix_dynamic_rpath %{pkg_name}

rm %{buildroot}/%{?_defaultlicensedir}%{!?_defaultlicensedir:%_docdir}/%{name}/LICENSE


%check
%if %{with tests}
%cabal test
%endif


%post -n ghc-%{name}-devel
%ghc_pkg_recache


%postun -n ghc-%{name}-devel
%ghc_pkg_recache


%files
%license LICENSE
%doc ChangeLog.md README.md
%{_bindir}/%{name}


%files -n ghc-%{name} -f ghc-%{name}.files
%license LICENSE


%files -n ghc-%{name}-devel -f ghc-%{name}-devel.files
%doc README.md


%changelog
* Sun Dec 04 2016 Róman Joost <roman@bromeco.de> - 0.4.0.0-1.20161204
- use a different macro to remove the license from the buildroot during
  build

* Mon Nov 28 2016 Róman Joost <roman@bromeco.de> - 0.4.0.0-1.20161127
- GHC 7.10.3 upgrade

* Thu Nov 17 2016 Róman Joost <roman@bromeco.de> - 0.4.0.0-1
- 0.4 release

* Tue Nov 15 2016 Fedora Haskell SIG <haskell@lists.fedoraproject.org> - 0.3.1.0-0.20161115
- spec file generated by cabal-rpm-0.9.10