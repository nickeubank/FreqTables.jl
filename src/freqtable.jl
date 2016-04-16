import Base.ht_keyindex

function freqtable(x::AbstractVector...;
                   # Parametric unions are currently not supported for keyword arguments,
                   # so weights are restricted to Float64 for now
                   # https://github.com/JuliaLang/julia/issues/3738
                   weights::Union{Void, AbstractVector{Float64}} = nothing,
                   subset::Union{Void, AbstractVector{Int}, AbstractVector{Bool}} = nothing)
    n = length(x)

    if subset != nothing
        x = ntuple(i -> x[i][subset], n)

        if weights != nothing
            weights = weights[subset]
        end
    end

    l = map(length, x)
    vtypes = map(eltype, typeof(x).parameters)

    for i in 1:n
        if l[1] != l[i]
            error("arguments are not of the same length: $l")
        end
    end

    if weights != nothing && length(weights) != l[1]
        error("'weights' (length $(length(weights))) must be of the same length as vectors (length $(l[1]))")
    end

    counttype = weights == nothing ? Int : eltype(weights)
    d = Dict{Tuple{vtypes...}, counttype}()

    for (i, el) in enumerate(zip(x...))
        index = ht_keyindex(d, el)

        if weights == nothing
            if index > 0
                d.vals[index] += 1
            else
                d[el] = 1
            end
        else
            @inbounds w = weights[i]

            if index > 0
                d.vals[index] += w
            else
                d[el] = w
            end
        end
    end

    k = collect(keys(d))

    dimnames = cell(n)
    for i in 1:n
        s = Set{vtypes[i]}()
        for j in 1:length(k)
            push!(s, k[j][i])
        end

        dimnames[i] = unique(s)
        T = eltype(dimnames[i])
        if method_exists(isless, (T, T))
            sort!(dimnames[i])
        end
    end

    a = zeros(counttype, ntuple(i -> length(dimnames[i]), n))
    na = NamedArray(a, ntuple(i -> dimnames[i], n), ntuple(i -> "Dim$i", n))

    for (k, v) in d
        na[k...] = v
    end

    na
end

function freqtable(x::PooledDataVector...; usena::Bool = false)
	n = length(x)
	len = [length(y) for y in x]

	for i in 1:n
	    if len[1] != len[i]
	        error(string("arguments are not of the same length: ", tuple(len...)))
	    end
	end

	lev = [levels(y) for y in x]

	if usena
        dims = ntuple(i -> length(lev[i]) + 1, n)
	    sizes = cumprod([dims...])
	    a = zeros(Int, dims)

	    for i in 1:len[1]
	        el = Int(x[1].refs[i])

            if el == 0
	            el = dims[1]
	        end

	        for j in 2:n
	            val = Int(x[j].refs[i])

	            if val == zero(val)
	                val = dims[j]
	            end

	            el += Int((val - 1) * sizes[j - 1])
	        end

	        a[el] += 1
	    end

	    NamedArray(a, ntuple(i -> [lev[i], "NA"], n), ntuple(i -> "Dim$i", n))
	else
        dims = ntuple(i -> length(lev[i]), n)
	    sizes = cumprod([dims...])
	    a = zeros(Int, dims)

	    for i in 1:len[1]
	        pos = (x[1].refs[i] != zero(UInt))
	        el = Int(x[1].refs[i])

	        for j in 2:n
	            val = x[j].refs[i]

	            if val == zero(val)
	                pos = false
	                break
	            end

	            el += Int((val - 1) * sizes[j - 1])
	        end

	        if pos
	            @inbounds a[el] += 1
	        end
	    end

	    NamedArray(a, ntuple(i -> lev[i], n), ntuple(i -> "Dim$i", n))
	end
end

function freqtable(d::DataFrame, x::Symbol...; args...)
    a = freqtable([d[y] for y in x]...; args...)
    setdimnames!(a, x)
    a
end
