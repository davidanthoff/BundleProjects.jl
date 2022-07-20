# BundleProjects.jl

To use, make sure there is a Julia project in your working directory, and then run

```julia
using FilePaths, BundleProjects

bundle(joinpath(home(), "outputpathforbundle"), packages=["PackageA", "PackageB"])
```

This will copy the content of the current folder to `~/outputpathforbundle`, then create a folder called
`~/outputpathforbundle/packages` (you can change the name of this with the keyword argument `packages_dir`)
and download the exact versions of PackageA and PackageB that are recorded in the `Manifest.toml` into this
new packages folder.
