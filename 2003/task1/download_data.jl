"""
This CLI script downloads all task 1 data from [2003 KDD cup](http://www.cs.cornell.edu/projects/kddcup/datasets.html). 

Usage:
    julia download_data.jl -- data_dir
"""

using Base.Filesystem: abspath, isdir, readdir
using Logging: @info

using CodecZlib
using Glob
using Tar


function make_filenames(years::Union{Vector{Int64}, UnitRange{Int64}})
    names = ["hep-th-abs.tar.gz", "hep-th-slacdates.tar.gz", "hep-th-citations.tar.gz"]
    for year in years
        push!(names, "hep-th-$year.tar.gz")
    end
    names
end

function extract_gzipped_tarball(source::String, destination::String)
    @info "Extract: $source -> $destination"
    open(CodecZlib.GzipDecompressorStream, source) do io
        Tar.extract(io, destination)
    end

end

years = 1992:2003
base_url = "http://www.cs.cornell.edu/projects/kddcup/download/"
@assert length(ARGS) == 1 "'$(splitdir(@__FILE__)[end])' takes a single command line argument: 'data_dir'."
data_dir = abspath(ARGS[1])
!isdir(data_dir) && mkdir(data_dir)

for filename in make_filenames(years)
    link = joinpath(base_url, filename)
    filepath = joinpath(data_dir, filename)
    @info "Download: $link -> $filepath"
    download(link, filepath)
    extract_gzipped_tarball(filepath, joinpath(data_dir, split(filename, ".")[begin]))
end

# Annoyingly, Tar.extract does not allow to extract to a non-empty directory.
# Consolidating the data into one directory per year is of the order
years_set = years |> x -> string.(x) |> Set
for (root, dirs, files) in walkdir(data_dir)
    root_name = splitdir(root)[end]
    if root_name in years_set
        for f in files
            source = joinpath(root, f)
            destination_dir = joinpath(data_dir, root_name)
            destination = joinpath(destination_dir, f)
            !ispath(destination_dir) && mkdir(destination_dir)
            @info "Copy: $source -> $destination"
            cp(source, destination)
        end
    end
end

# Once again, since Tar.extract does not allow to extract to a non-empty directory,
# we remove an unnecessary directory level
for name in ["hep-th-slacdates", "hep-th-citations"]
    destination = joinpath(data_dir, name)
    source = joinpath(destination, name)
    tmp_destination = joinpath("/tmp", name)
    @info "Copy: $source -> $tmp_destination"
    cp(source, tmp_destination, force=true)
    @info "Delete: $destination"
    rm(destination, recursive=true)
    @info "Copy: $tmp_destination -> $destination"
    cp(tmp_destination, destination)
end

# Teardown
for path in readdir(data_dir, join=true)
    if (occursin(r"\.tar\.gz$", path) || 
        (isdir(path) && occursin(r"^hep\-th", splitdir(path)[end])))
        @info "Remove: $path"
        rm(path, recursive=true)
    end
end
