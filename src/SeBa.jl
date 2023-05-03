module SeBa
    using DataFrames, Unitful, UnitfulAstro
    const SEBADIR = joinpath(@__DIR__, "..", "deps", "SeBa_c")

    function make_seba(seba_path)
        success = true
        try
            cd(f, seba_path) do f
                run(`make clean`)
                run(`make`)
                cd(f2, cd("dstar")) do f2
                    run(`make`)
                end
            end
        catch e
            success = false
            @error e
        finally
            return success
        end
    end

    function run_seba(seba_path=SEBADIR; runfile="SeBa", make=false, verbose=false, montecarlo=false, args...)
        if make
            @info "Compiling SeBa at $seba_path"
            success = make_seba(seba_path)
            if !success
                @info "Unable to compile SeBa. Aborting."
                return 0command_args
            end
        end

        args = Dict(args)

        if :input_file in keys(args)
            command_args = ["-I", "$(args[:input_file])"]
        else
            command_args = [["-$arg", "$val"] for (arg, val) in args]
            command_args = reduce(vcat, command_args)
            if montecarlo
                pushfirst!(command_args, "-R")
            end
        end

        if verbose
            @info "Running SeBa with parameters" args
            println()
        end
        
        runfile_path = joinpath(seba_path, "dstar")
        @assert isfile(joinpath(runfile_path, runfile)) "Runfile $runfile at $runfile_path not found."

        try
            run_command = if isempty(args) 
                              `./$runfile`
                          else
                              `./$runfile $command_args`
                          end     
            @show run_command
            cd(() -> run(run_command), runfile_path)
        catch e
            throw(e)
        end

    end


    function read_seba_output(filepath=joinpath(SEBADIR, "dstar"), filename="SeBa.data")

        infile = joinpath(filepath, filename)
        @assert isfile(infile) "File $filename not found at $filepath."

        dataframe = DataFrame(BinaryIdentity   = typeof(1u"1")[],      BinaryType     = typeof(1u"1")[], 
                              MassTransferType = typeof(1u"1")[],      Time           = typeof(1.0u"Myr")[], 
                              Separation       = typeof(1.0u"Rsun")[], Eccentricity   = typeof(1.0u"1")[],
                              StellarIdentity1 = typeof(1u"1")[],      StarType1      = typeof(1u"1")[], 
                              StellarMass1     = typeof(1.0u"Msun")[], StellarRadius1 = typeof(1.0u"Rsun")[], 
                              logTeff1         = typeof(1.0u"1")[],    CoreMass1      = typeof(1.0u"Msun")[],
                              StellarIdentity2 = typeof(1u"1")[],      StarType2      = typeof(1u"1")[], 
                              StellarMass2     = typeof(1.0u"Msun")[], StellarRadius2 = typeof(1.0u"Rsun")[], 
                              logTeff2         = typeof(1.0u"1")[],    CoreMass2      = typeof(1.0u"Msun")[])


        open(infile, "r+") do seba_file
            for ln in eachline(seba_file)
                words = strip.(split(ln))

                vals_with_units = []
                for (w, c) in zip(words, eachcol(dataframe))
                    w = ifelse(occursin("nan", w), replace(w, "nan" => "NaN"), w)
                    unit_ = unit(eltype(c))
                    unit_s = replace(string(unit_), "⊙" => "sun")
                    word_with_unit = unit_ == NoUnits ? uparse(w) : uparse("$w*$unit_s", unit_context=[Unitful, UnitfulAstro])
                    push!(vals_with_units, word_with_unit)
                end
                push!(dataframe, vals_with_units)

            end
        end

        dataframe
    end
end

"""
columns (starting at column 1):
column 1 binary identity number 
column 2 binary type
column 3 mass transfer type
column 4 time
column 5 separation in Solar radii
column 6 eccentricity
column 7 & 13 stellar identity number (either 0 or 1)
column 8 & 14 star type
column 9 & 15 stellar mass in Solar mass
column 10 & 16 stellar radius in Solar radii
column 11 & 17 log of effective temperature
column 12 & 18 core mass in Solar mass
""";