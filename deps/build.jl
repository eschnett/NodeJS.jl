using BinDeps
using BinDeps: MakeTargets

basedir = @__DIR__
prefix = joinpath(basedir, "usr")

nodejs_version = v"6.10.3"
base_url = "https://nodejs.org/dist/v$nodejs_version"

@static if is_windows()
    binary_name = "node.exe"
else
    binary_name = "node"
end

function install_binaries(file_base, file_ext, binary_dir)
    filename = "$(file_base).$(file_ext)"
    url = "$(base_url)/$(filename)"
    binary_path = joinpath(basedir, "downloads", file_base, binary_dir)

    @static if is_windows()
        install_step = () -> begin
            for dir in readdir(dirname(binary_path))
                cp(string("\\\\?\\", joinpath(dirname(binary_path), dir)), string("\\\\?\\", joinpath(prefix, dir)), remove_destination=true)
            end
        end
    else
        install_step = () -> begin
            for file in readdir(binary_path)
                symlink(joinpath(binary_path, file), 
                        joinpath(prefix, "bin", file))
            end
        end
    end

    function test_step()
        try
            run(`$(joinpath(prefix, binary_name)) --version`)
        catch e
            error("""
Running the precompiled node binary failed with the error
$(e)
To build from source instead, run:
    julia> ENV["CMAKEWRAPPER_JL_BUILD_FROM_SOURCE"] = 1
    julia> Pkg.build("CMakeWrapper")
""")
        end
    end
    (@build_steps begin
        FileRule(joinpath(prefix, binary_name), 
            (@build_steps begin
                FileDownloader(url, joinpath(basedir, "downloads", filename))
                FileUnpacker(joinpath(basedir, "downloads", filename),
                             joinpath(basedir, "downloads"), 
                             "")
                CreateDirectory(prefix)
                install_step
                test_step
            end))
    end)
end

# function install_from_source(file_base, file_ext)
#     filename = "$(file_base).$(file_ext)"
#     url = "$(base_url)/$(filename)"

#     (@build_steps begin
#         FileRule(joinpath(prefix, "bin", binary_name), 
#             (@build_steps begin
#                 FileDownloader(url, joinpath(basedir, "downloads", filename))
#                 CreateDirectory(joinpath(basedir, "src"))
#                 FileUnpacker(joinpath(basedir, "downloads", filename),
#                              joinpath(basedir, "src"), 
#                              "")
#                 begin
#                     ChangeDirectory(joinpath(basedir, "src", file_base))
#                     `./configure --prefix=$(prefix)`
#                     MakeTargets()
#                     MakeTargets("install")
#                 end
#             end))
#     end)
# end

force_source_build = false # lowercase(get(ENV, "CMAKEWRAPPER_JL_BUILD_FROM_SOURCE", "")) in ["1", "true"]

# "https://nodejs.org/dist/v6.10.3/node-v6.10.3-win-x64.zip"
# "https://nodejs.org/dist/v6.10.3/node-v6.10.3-darwin-x64.tar.gz"
# "https://nodejs.org/dist/v6.10.3/node-v6.10.3-linux-x64.tar.xz"

process = @static if is_linux()
    if Sys.ARCH == :x86_64 && !force_source_build
        install_binaries(
            "cmake-$(nodejs_version)-Linux-x86_64",
            "tar.gz",
            "bin")
    else
        install_from_source("cmake-$(nodejs_version)", "tar.gz")
    end
elseif is_apple()
    if !force_source_build
        install_binaries(
            "cmake-$(nodejs_version)-Darwin-x86_64",
            "tar.gz",
            joinpath("CMake.app", "Contents", "bin"))
    else
        install_from_source("cmake-$(nodejs_version)", "tar.gz")
    end
elseif is_windows()
    if sizeof(Int) == 8
        install_binaries(
            "node-v$(nodejs_version)-win-x64",
            "zip",
            "bin")
    elseif sizeof(Int) == 4
        install_binaries(
            "node-v$(nodejs_version)-win-x86",
            "zip",
            "bin")
    else
        error("Only 32- or 64-bit architectures are supported")
    end
else
    error("Sorry, I couldn't recognize your operating system.")
end

run(process)

open(joinpath(dirname(@__FILE__), "deps.jl"), "w") do f
    write(f, """
const node_executable = "$(escape_string(joinpath(prefix, binary_name)))"
""")

end