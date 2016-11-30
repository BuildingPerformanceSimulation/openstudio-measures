# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class SetBuildingToConstructionSet < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Set Building To Construction Set"
  end

  # human readable description
  def description
    return "This measures changes the building's default construction set to one selected by the user from a list of available default construction sets."
  end

  # human readable description of modeling approach
  def modeler_description
    return "No checking of any sorts is performed. The available default construction sets are obtained via the constructionset = SELECTFROM(model.getDefaultConstructionSets) method and the seleted construction set is applied via the building = model.getBuilding and building.setDefaultConstructionSet(constructionset) methods."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # populate choice arguments for construction sets
    constructionset_handles = OpenStudio::StringVector.new
    constructionset_display_names = OpenStudio::StringVector.new

    # put construction sets into hash
    constructionset_args = model.getDefaultConstructionSets
    constructionset_args_hash = {}
    constructionset_args.each do |constructionset_arg|
      constructionset_args_hash[constructionset_arg.name.to_s] = constructionset_arg
    end

    # loop through sorted hash of construction sets
    constructionset_args_hash.sort.map do |key,value|
      constructionset_handles << value.handle.to_s
      constructionset_display_names << key
    end

    # make argument for construction set
    constructionset = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("constructionset", constructionset_handles, constructionset_display_names,true)
    constructionset.setDisplayName("Select new construction set:")
    args << constructionset

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    constructionset = runner.getOptionalWorkspaceObjectChoiceValue("constructionset",user_arguments,model)

    # check the construction set for reasonableness
    if constructionset.empty?
      handle = runner.getStringArgumentValue("constructionset",user_arguments)
      if handle.empty?
        runner.registerError("No construction set was chosen.")
      else
        runner.registerError("The selected construction set with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not constructionset.get.to_DefaultConstructionSet.empty?
        constructionset = constructionset.get.to_DefaultConstructionSet.get
      else
        runner.registerError("Script Error - argument not showing up as construction set.")
        return false
      end
    end

    # effect the change
    building = model.getBuilding
    building.setDefaultConstructionSet(constructionset)
    runner.registerInfo("Setting default Construction Set for building to #{building.defaultConstructionSet.get.name}")

    return true

  end
  
end

# register the measure to be used by the application
SetBuildingToConstructionSet.new.registerWithApplication
