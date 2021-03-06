"""
    For loading networks with stoichiometry stored in matrices.
    Assumed that the substrate and product stoichiometry matrices
    are stored as numspecies by numrxs matrices, with entry (i,j)
    giving the stoichiometric coefficient of species i within rx j.
"""


""" 
    For dense matrices
"""
function loadrxnetwork(ft::MatrixNetwork, 
                        rateexprs::AbstractVector, 
                        substoich::AbstractMatrix, 
                        prodstoich::AbstractMatrix; 
                        species::AbstractVector=Any[], 
                        params::AbstractVector=Any[],
                        iv=Variable(:t))

    sz = size(substoich)
    @assert sz == size(prodstoich)
    numspecs = sz[1]
    numrxs = sz[2]

    # create the network
    rn = make_empty_network()    
    t  = independent_variable(rn)

    # create the species if none passed in    
    
    isempty(species) && (species = [funcsym(:S,i)(t) for i=1:numspecs])
    foreach(s -> addspecies!(rn, s, disablechecks=true), species)

    # create the parameters
    foreach(p -> addparam!(rn, p, disablechecks=true), params)

    # create the reactions
    # we need to create new vectors each time as the ReactionSystem
    # takes ownership of them
    for j = 1:numrxs
        subs    = Any[]
        sstoich = Vector{eltype(substoich)}()
        prods   = Any[]
        pstoich = Vector{eltype(prodstoich)}()
    
        # stoich
        for i = 1:numspecs
            scoef = substoich[i,j]
            if (scoef > zero(scoef)) 
                push!(subs, species[i])
                push!(sstoich, scoef)
            end

            pcoef = prodstoich[i,j]
            if (pcoef > zero(pcoef)) 
                push!(prods, species[i])
                push!(pstoich, pcoef)
            end
        end

        addreaction!(rn, Reaction(rateexprs[j], subs, prods, sstoich, pstoich))
    end

    ParsedReactionNetwork(rn, nothing)
end

""" 
    For sparse matrices
"""
function loadrxnetwork(ft::MatrixNetwork,
                        rateexprs::AbstractVector, 
                        substoich::SparseMatrixCSC, 
                        prodstoich::SparseMatrixCSC; 
                        species::AbstractVector=Any[], 
                        params::AbstractVector=Any[])

    sz = size(substoich)
    @assert sz == size(prodstoich)
    numspecs = sz[1]
    numrxs = sz[2]

    # create the network
    rn = make_empty_network()
    t  = independent_variable(rn)

    # create the species if none passed in
    isempty(species) && (species = [funcsym(:S,i)(t) for i=1:numspecs])
    foreach(s -> addspecies!(rn, s, disablechecks=true), species)

    # create the parameters
    foreach(p -> addparam!(rn, p, disablechecks=true), params)

    # create the reactions
    srows = rowvals(substoich)
    svals = nonzeros(substoich)
    prows = rowvals(prodstoich)
    pvals = nonzeros(prodstoich)
    for j = 1:numrxs
        subs    = Any[]
        sstoich = Vector{eltype(substoich)}()
        prods   = Any[]
        pstoich = Vector{eltype(prodstoich)}()

        for ir in nzrange(substoich, j)
           i     = srows[ir]
           scoef = svals[ir]
           if scoef > zero(scoef)
                push!(subs, species[i])
                push!(sstoich, scoef)
           end
        end

        for ir in nzrange(prodstoich, j)
            i     = prows[ir]
            pcoef = pvals[ir]
            if pcoef > zero(pcoef)
                push!(prods, species[i])
                push!(pstoich, pcoef)
            end
        end

        addreaction!(rn, Reaction(rateexprs[j], subs, prods, sstoich, pstoich))
     end

    ParsedReactionNetwork(rn, nothing)
end
