class ExcludePlenumsFromFloorArea < OpenStudio::Ruleset::ModelUserScript

  def name
    return "ExcludePlenumsFromFloorArea"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    plenums_found = 0
    plenums_changed = 0
    model.getSpaces.each do |space|
      if space.name.to_s.downcase.include? "plenum"
        plenums_found += 1        
        if space.partofTotalFloorArea
          plenums_changed += 1
          space.setPartofTotalFloorArea(false)
        end        
      end
    end

    #reporting final condition of model
    runner.registerFinalCondition("#{plenums_found} plenum spaces found in the model.  #{plenums_changed} were changed to no longer be counted towards the model total floor area.")
    
    return true

  end
  
end

# register the measure to be used by the application
ExcludePlenumsFromFloorArea.new.registerWithApplication
