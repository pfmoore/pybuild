pybuild - A Windows build environment for Python
================================================

Overview
--------

In order to set up a Python build environment on Windows, a number of pieces
of software are needed, some of which can be tricky to set up correctly. As
many Python developers use Unix as their primary environment, setting up a
Windows build environment can be a significant challenge.

The purpose of this project is to simplify that process as much as possible,
in order to encourage more developers to provide binary wheels for Windows.

Assumptions
-----------

The build is assumed to be installed on a 64-bit Windows system. This is
necessary as 32-bit environments cannot build 64-bit software, although the
converse is true.

The target Windows system is expected to have Powershell installed, as the
build scripts are written in Powershell. A minimum of Powershell version 2 is
needed. Windows systems from Windows 7, and Windows Server 2008 R2, come with
Powershell version 2 or later preinstalled.

Ther target system is assumed to be essentially a clean build of Windows. In
particular, no C compilers should already be installed. This is simply a matter
of practicality - the software installers being run typically do not document
how they react when encountering products that are already installed, and there
are simply too many possible combinations to test them all. The scripts *may*
work, but aren't supported in such situations. Patches to improve support for
such scenarios are welcome, as are reports of cases where the scripts work on
more complex target systems.

The scripts do not roll back should an error be encountered. As a result, it is
assumed that should an error occur, the user will have to clean up before
rerunning the script. The ideal target system is a newly built Windows virtual
machine, with a snapshot taken before running the build. Recovery is then
simply a case of restoring the snapshot.

Supported Versions
------------------

The pybuild project supports building binaries for both 32-bit and 64-bit
Windows systems, for Python versions 2.7, 3.3 and 3.4.

Python versions older than 2.7 are not supported, and nor is building without
using setuptools. However, note that many projects that use pure distutils in
their setup.py will still work, as pip injects setuptools into the build
process automatically. Only projects that make heavy use of distutils
customisations, in ways that are incompatible with setuptools, should find this
an issue in practice.

The reasons for the above limitations are that the "Visual C for Python 2.7"
compiler package from Microsoft is used by pybuild, and the limitations are
directly inherited from that package.

Python 3 support, on the other hand, is simply a matter of convenience. Python
3.3 and 3.4 are the versions commonly in use, and so the scripts have been set
up to install those versions. Python 3.2 support could be easily added by
updating the scripts. Python 3.5 and later will be supported when new versions
are released.

Licensing
---------

All of the tools installed are free of charge. Checking software licenses is
the responsibility of the user, but the non-Microsoft software installed is
under open source compatible licenses, and the Microsoft licenses are believed
to be acceptable for this type of use. However, the author of the scripts
takes no responsibility for any license implications involved in running the
scripts.

Software installed is:

- 7-Zip
- .NET Framework 4.0
- Windows SDK 7.1
- Visual C for Python
- Visual C 2008 redistributables (required for Python 2.7)
- Python 2.7, 3.3 and 3.4, 32-bit and 64-bit versions

Customisations
--------------

The Python 3.3 and 3.4 installations created by the scripts have a
```sitecustomize``` file installed that enables the SDK compilers whenever
Python is run. It does this by setting the SDK environment variables in the
Python process. This may cause unexpected results if the installed Python
interpreters are used for general purposes rather than for package builds. No
such issues are expected, and bug reports are welcome if they do, but users
should be aware that the Python installations are set up first and foremost for
building extensions.

All the installations have distutils configured to look in a central directory
for additional libraries. The locations are:

- ```C:\Libraries\Include``` - C header files
- ```C:\Libraries\Lib32``` - 32-bit object libraries
- ```C:\Libraries\Lib64``` - 64-bit object libraries

This is intended as a convenience for builds that link to C libraries, but are
written with an assumption that such libraries have been "installed centrally"
(which is the norm on Unix, but not on Windows where there is normally no
central install location).
