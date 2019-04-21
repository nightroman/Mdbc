# Mdbc development notes

## Mdbc for net-core

User request: [#20](https://github.com/nightroman/Mdbc/issues/20).

The net-core is built with netstandard2.0 using [PowerShellStandard](https://github.com/PowerShell/PowerShellStandard).
This package is supposed to work for PowerShell v5-6 but not for v3-4.
We would like to support v3-4.

It is not clear how to distribute two different builds of Mdbc using PSGallery
and the same module name, i.e. Mdbc for Windows PowerShell and Mdbc for
PowerShell Core.

Thus, the current solution:

- The PSGallery module and NuGet package are for Windows PowerShell v3-5, "as usual".
- The new net-core zip is added/downloaded manually at [Releases](https://github.com/nightroman/Mdbc/releases).

## Why legacy C# driver

- The legacy driver is still supported by the developers.
- The modern driver looks less friendly for PowerShell.

Thus, we will stay with the legacy driver for while.
