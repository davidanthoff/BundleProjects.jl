module BundleProjects

export bundle

import FilePathsBase, TOML, URIs, LibGit2, RegistryInstances

using FilePathsBase: cwd, absolute, exists, mktmpdir
using URIs: URI

function find_project(path)
    project_file_path = exists(joinpath(path, "Project.toml")) ? joinpath(path, "Project.toml") : exists(joinpath(path, "JuliaProject.toml")) ? joinpath(path, "JuliaProject.toml") : nothing
    manifest_file_path = exists(joinpath(path, "Manifest.toml")) ? joinpath(path, "Manifest.toml") : exists(joinpath(path, "JuliaManifest.toml")) ? joinpath(path, "JuliaManifest.toml") : nothing

    return project_file_path===nothing || manifest_file_path===nothing ? nothing : (project=project_file_path, manifest=manifest_file_path)
end

function bundle(output_path::FilePathsBase.SystemPath; packages_dir::Union{Nothing,String}=nothing, packages::Vector{String}=[], force::Bool=false)
    project_paths = find_project(cwd())

    project_paths===nothing && error("No project found.")

    manifest_content = TOML.parsefile(string(project_paths.manifest))

    if get(manifest_content, "manifest_format", "") == "2.0"
        manifest_content = manifest_content["deps"]
    end

    for pkg in packages
        if !haskey(manifest_content, pkg)
            error("Package $pkg not found in project manifest file.")
        end

        if !haskey(manifest_content[pkg][1], "git-tree-sha1")
            error("Package $pkg does not have a `git-tree-sha1` element in the project manifest file.")
        end
    end

    packages_dir = packages_dir===nothing ? "packages" : packages_dir

    abs_output_path = absolute(output_path)

    if !force && exists(abs_output_path)
        error("Output path $output_path already exists, use the force=true argument to force an overwrite.")
    end

    credentials = nothing

    if credentials===nothing        
        creds = LibGit2.GitCredential(LibGit2.GitConfig(), "https://github.com")

        creds.password===nothing && error("Did not find credentials for github.com in the git credential manager.")

        credentials = read(creds.password, String)
        Base.shred!(creds.password)
    end

    mktmpdir() do path        
        temp_output_path = joinpath(path, "foo")
        abs_packages_path = joinpath(temp_output_path, packages_dir)

        cp(cwd(), temp_output_path)

        if exists(joinpath(temp_output_path,".git"))
            rm(joinpath(temp_output_path, ".git"), recursive = true)
        end

        if length(packages)>0            
            mkpath(abs_packages_path)

            for pkg in packages
                @info "Downloading $pkg."

                abs_package_path = joinpath(abs_packages_path, pkg)

                mkpath(abs_package_path)

                pkg_node = manifest_content[pkg][1]

                repourl = if haskey(pkg_node, "repo-url")
                    URI(pkg_node["repo-url"])
                else
                    general_registry = only(
                        filter(
                            x -> x.name == "General",
                            RegistryInstances.reachable_registries(),
                        )
                    )

                    x = general_registry.pkgs[Base.UUID(pkg_node["uuid"])]

                    URI(TOML.parse(x.in_memory_registry[x.path * "/Package.toml"])["repo"])
                end

                if repourl.scheme!="https" || repourl.host!="github.com"
                    error("Invalid URL")
                end

                repo_path = endswith(repourl.path, ".git") ? repourl.path[1:end-4] : repourl.path

                apiurl = URI(scheme="https", host="api.github.com", path="/repos$repo_path/tarball/$(pkg_node["git-tree-sha1"])")

                auth_header = "Authorization: token $credentials"
                
                run(pipeline(`curl --header $auth_header -fsSL $apiurl`, `tar -xzf - -C $abs_package_path --strip-components 1`))
            end

            pkg_paths = map(packages) do pkg
                string("(;path=", '"', replace(joinpath(packages_dir, pkg), "\\" => "/"), '"', ')')
            end

            foo = "using Pkg; Pkg.develop([$(join(pkg_paths, ","))])"

            @info "Updating manifest file."
            run(pipeline(Cmd(`julia --project=$temp_output_path -e $foo`, dir=string(temp_output_path)), stderr=devnull))
        end

        mv(temp_output_path, abs_output_path, force=true)
    end

    nothing
end

end # module
