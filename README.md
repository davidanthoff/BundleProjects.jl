# BundleProjects.jl

## Overview

This package makes it easy to take a Julia project, and bundle a specific list of packages that are
used in this project into a sub folder. This can be useful for example in the preparation of replication
archives for journal submissions.

## Status

At the moment this package won't easily work because we are waiting for https://github.com/GunnarFarneback/RegistryInstances.jl
to be registered in the general registry.

## Example

To use, make sure there is a Julia project in your working directory, and then run

```julia
using FilePaths, BundleProjects

bundle(joinpath(home(), "outputpathforbundle"), packages=["PackageA", "PackageB"])
```

This will copy the content of the current folder to `~/outputpathforbundle`, then create a folder called
`~/outputpathforbundle/packages` (you can change the name of this with the keyword argument `packages_dir`)
and download the exact versions of PackageA and PackageB that are recorded in the `Manifest.toml` into this
new packages folder.
