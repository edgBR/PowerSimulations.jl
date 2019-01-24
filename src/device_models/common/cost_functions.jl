function ps_cost(ps_m::CanonicalModel, variable::JuMP.Containers.DenseAxisArray{JuMP.VariableRef}, cost_component::Function)

    store = Array{JuMP.AbstractJuMPScalar,1}(undef,length(variable))

    for (ix, element) in enumerate(variable)
        store[ix] = cost_component(element)
    end

    gen_cost = sum(store)

    return gen_cost

end


function ps_cost(ps_m::CanonicalModel, variable::JuMP.Containers.DenseAxisArray{JuMP.VariableRef}, cost_component::Float64)

    gen_cost = sum(variable)*cost_component

    return gen_cost

end

function pwlgencost(ps_m::CanonicalModel, variable::JuMP.VariableRef, cost_component::Array{Tuple{Float64, Float64}})

    gen_cost = AffExpr()
    pwlvars = JuMP.@variable(m, [i = 1:(length(cost_component)-1)], base_name = "{$(variable)}_pwl", start = 0.0, lower_bound = 0.0, upper_bound = (cost_component[i+1][1] - cost_component[i][1]))
     for (ix, pwlvar) in enumerate(pwlvars)
        c = JuMP.@constraint(m, pwlvar <= cost_component[ix + 1][2])
        c = JuMP.@constraint(m, pwlvar >= 0)
        gen_cost = JuMP.add_to_expression!(gen_cost, (
            cost_component[ix + 1][1] * cost_component[ix + 1][2] - cost_component[ix][1] * cost_component[ix][2]
        ) / ( cost_component[ix + 1][2] - cost_component[ix][2] ) * pwlvar)
    end

    c = JuMP.@constraint(m, variable == sum(pwlvars[ix] for (ix, pwlvar) in enumerate(pwlvars)))

    return gen_cost

end

function ps_cost(ps_m::CanonicalModel, variable::JuMP.Containers.DenseAxisArray{JuMP.VariableRef}, cost_component::Array{Tuple{Float64, Float64}})

    gen_cost = JuMP.AffExpr()

    for var in variable
        c = pwlgencost(ps_m.JuMPmodel, var, cost_component)
        JuMP.add_to_expression!(gen_cost,c)
    end

    return gen_cost

end

function add_to_cost(ps_m::CanonicalModel, devices::Array{C,1}, var_name::String, cost_symbol::Symbol) where {C <: PSY.PowerSystemDevice}

   for d in devices 
        
        cost_expression = ps_cost(ps_m, ps_m.variables["$(var_name)"][d.name,:], getfield(d.econ,cost_symbol))
        
        if !isa(ps_m.cost_function, Nothing)

            if (isa(ps_m.cost_function,JuMP.AffExpr) && isa(cost_expression,JuMP.AffExpr))

                JuMP.add_to_expression!(ps_m.cost_function,cost_expression)

            elseif (isa( ps_m.cost_function,JuMP.GenericQuadExpr) && isa(cost_expression,JuMP.GenericQuadExpr))

                JuMP.add_to_expression!(ps_m.cost_function,cost_expression)

             else

                ps_m.cost_function += cost_expression

            end

        else

        ps_m.cost_function = cost_expression
            
        end

    end

end