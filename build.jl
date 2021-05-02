using Pkg.Artifacts
using Pkg.BinaryPlatforms
using URIParser, FilePaths

pkgname = "NodeJS"
version = v"12.22.1"
build = 0

build_path = joinpath(@__DIR__, "build")

if ispath(build_path)
    rm(build_path, force=true, recursive=true)
end

mkpath(build_path)

artifact_toml = joinpath(build_path, "Artifacts.toml")

platforms = [
    # glibc Linuces
    Linux(:i686),
    Linux(:x86_64),
    Linux(:aarch64),
    Linux(:armv7l),
    Linux(:powerpc64le),

    # musl Linuces
    Linux(:i686, libc=:musl),
    Linux(:x86_64, libc=:musl),
    Linux(:aarch64, libc=:musl),
    Linux(:armv7l, libc=:musl),

    # BSDs
    MacOS(:x86_64),
    # MacOS(:aarch64),
    FreeBSD(:x86_64),

    # Windows
    Windows(:i686),
    Windows(:x86_64),
]

mktempdir() do temp_path

    for platform in platforms
        if platform isa Windows && arch(platform)==:x86_64
            download_url = "https://nodejs.org/dist/v$version/node-v$version-win-x64.zip"
        elseif platform isa Windows && arch(platform)==:i686
            download_url = "https://nodejs.org/dist/v$version/node-v$version-win-x86.zip"
        elseif platform isa MacOS
            # TODO At some point use Apple silicon binaries
            download_url = "https://nodejs.org/dist/v$version/node-v$version-darwin-x64.tar.gz"
        elseif platform isa Linux && arch(platform)==:x86_64
            download_url = "https://nodejs.org/dist/v$version/node-v$version-linux-x64.tar.xz"
        elseif platform isa Linux && arch(platform)==:armv7l
            download_url = "https://nodejs.org/dist/v$version/node-v$version-linux-armv7l.tar.xz"
        elseif platform isa Linux && arch(platform)==:powerpc64le
            download_url = "https://nodejs.org/dist/v$version/node-v$version-linux-ppc64le.tar.xz"
        else
            continue
        end

        download_filename = joinpath(Path(temp_path), Path(basename(Path(URI(download_url).path))))

        download(download_url, download_filename)

        product_hash = create_artifact() do artifact_dir
            if extension(download_filename) == "zip"
                run(Cmd(`unzip $download_filename -d $artifact_dir`))
            else
                run(Cmd(`tar -xvf $download_filename -C $artifact_dir`))
            end

            # Make sure everything is in the root folder
            files = readdir(artifact_dir)
            if length(files)==1
                stuff_to_move = readdir(joinpath(artifact_dir, files[1]))
                for f in stuff_to_move
                    mv(joinpath(artifact_dir, files[1], f), joinpath(artifact_dir, f))
                end
                rm(joinpath(artifact_dir, files[1]), force=true)
            end

            if platform isa Windows
                for (root, dirs, files) in walkdir(artifact_dir) 
                    cd(root) do
                        for file in files
                            if endswith(file, ".exe") || endswith(file, ".dll") || endswith(file, ".cmd")
                                run(`chmod +x $file`)
                            end
                        end
                    end
                end                
            end
        end

        archive_filename = "$pkgname-$version+$(build)-$(triplet(platform)).tar.gz"

        download_hash = archive_artifact(product_hash, joinpath(build_path, archive_filename))

        bind_artifact!(artifact_toml, "nodejs_app", product_hash, platform=platform, force=true, download_info=Tuple[("https://github.com/davidanthoff/NodeJSBuilder/releases/download/v$(URIParser.escape(string(version) * "+" * string(build)))/$archive_filename", download_hash)])
    end
end
