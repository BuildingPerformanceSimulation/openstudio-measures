class SwapConstructionInConstructionSet < OpenStudio::Ruleset::ModelUserScript

  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return "Swap Construction In Construction Set"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # make a choice argument for constructions
    construction_handles = OpenStudio::StringVector.new
    construction_display_names = OpenStudio::StringVector.new

    # putting space types and names into hash
    construction_args = model.getConstructions
    construction_args_hash = {}
    construction_args.each do |construction_arg|
      construction_args_hash[construction_arg.name.to_s] = construction_arg
    end

    # looping through sorted hash of model objects
    construction_args_hash.sort.map do |key,value|
      construction_handles << value.handle.to_s
      construction_display_names << key
    end

    # make a choice argument for old construction to be replaced
    old_construction = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("old_construction", construction_handles, construction_display_names,true)
    old_construction.setDisplayName("Pick a construction to be replaced:")
    args << old_construction
    
    # make a choice argument for new construction
    new_construction = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("new_construction", construction_handles, construction_display_names,true)
    new_construction.setDisplayName("Pick a construction to replace the old construction. This construction must the same type (Surface, Subsurface) as the old construction.")
    args << new_construction

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    old_construction = runner.getOptionalWorkspaceObjectChoiceValue("old_construction",user_arguments,model)
    new_construction = runner.getOptionalWorkspaceObjectChoiceValue("new_construction",user_arguments,model)

    # check the old construction for reasonableness
    if old_construction.empty?
      handle = runner.getStringArgumentValue("old_construction",user_arguments)
      if handle.empty?
        runner.registerError("No construction was chosen.")
      else
        runner.registerError("The selected construction with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not old_construction.get.to_Construction.empty?
        old_construction = old_construction.get.to_Construction.get
      else
        runner.registerError("Script Error - argument not showing up as construction.")
        return false
      end
    end  # end of if old_construction.empty?

    # check the new construction for reasonableness
    if new_construction.empty?
      handle = runner.getStringArgumentValue("new_construction",user_arguments)
      if handle.empty?
        runner.registerError("No construction was chosen.")
      else
        runner.registerError("The selected construction with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not new_construction.get.to_Construction.empty?
        new_construction = new_construction.get.to_Construction.get
      else
        runner.registerError("Script Error - argument not showing up as construction.")
        return false
      end
    end  # end of if new_construction.empty?
    
    # check for fenestration vs. opaque
    if (old_construction.isOpaque != new_construction.isOpaque) || (old_construction.isFenestration != new_construction.isFenestration)
      runner.registerError("old construction and new construction are not of the same type (opaque or fenestration)")
    end
    
    runner.registerInfo("This measure will replace #{old_construction.name.to_s} with #{new_construction.name.to_s}")
    
    num_swaps = 0
    # loop through construction sets used in the model
    default_construction_sets = model.getDefaultConstructionSets
    default_construction_sets.each do |default_construction_set|
    
      default_surface_construction_sets = []
      default_sub_surface_construction_sets = []
      default_ext_surface_const_set = default_construction_set.defaultExteriorSurfaceConstructions
      default_int_surface_const_set = default_construction_set.defaultInteriorSurfaceConstructions
      default_ground_surface_const_set = default_construction_set.defaultGroundContactSurfaceConstructions
      default_ext_sub_surface_const_set = default_construction_set.defaultExteriorSubSurfaceConstructions
      default_int_sub_surface_const_set = default_construction_set.defaultInteriorSubSurfaceConstructions
      default_int_partition_const = default_construction_set.interiorPartitionConstruction
      default_space_shade_const = default_construction_set.spaceShadingConstruction
      default_bldg_shade_const = default_construction_set.buildingShadingConstruction
      default_site_shade_const = default_construction_set.siteShadingConstruction
      
      default_surface_construction_sets << default_ext_surface_const_set
      default_surface_construction_sets << default_int_surface_const_set
      default_surface_construction_sets << default_ground_surface_const_set
      default_sub_surface_construction_sets << default_ext_sub_surface_const_set
      default_sub_surface_construction_sets << default_int_sub_surface_const_set
      
      default_surface_construction_sets.each do |default_surface_construction_set|
        if !default_surface_construction_set.empty?
          default_surface_construction_set = default_surface_construction_set.get
          floor_construction = default_surface_construction_set.floorConstruction
          if !floor_construction.empty?
            if floor_construction.get.name.to_s == old_construction.name.to_s
              default_surface_construction_set.setFloorConstruction(new_construction.to_ConstructionBase.get)
              num_swaps += 1
            end
          end
          wall_construction = default_surface_construction_set.wallConstruction
          if !wall_construction.empty?
            if wall_construction.get.name.to_s == old_construction.name.to_s
              default_surface_construction_set.setWallConstruction(new_construction.to_ConstructionBase.get)
              num_swaps += 1
            end
          end
          roof_construction = default_surface_construction_set.roofCeilingConstruction
          if !roof_construction.empty?
            if roof_construction.get.name.to_s == old_construction.name.to_s
              default_surface_construction_set.setRoofCeilingConstruction(new_construction.to_ConstructionBase.get)
              num_swaps += 1
            end
          end
        end
      end

      default_sub_surface_construction_sets.each do |default_sub_surface_construction_set|
        if !default_sub_surface_construction_set.empty?
          default_sub_surface_construction_set = default_sub_surface_construction_set.get
          fixed_window_construction = default_sub_surface_construction_set.fixedWindowConstruction
          if !fixed_window_construction.empty?
            if fixed_window_construction.get.name.to_s == old_construction.name.to_s
              default_sub_surface_construction_set.setFixedWindowConstruction(new_construction.to_ConstructionBase.get)
              num_swaps += 1
            end
          end
          operable_window_construction = default_sub_surface_construction_set.operableWindowConstruction
          if !operable_window_construction.empty?
            if operable_window_construction.get.name.to_s == old_construction.name.to_s
              default_sub_surface_construction_set.setOperableWindowConstruction(new_construction.to_ConstructionBase.get)
              num_swaps += 1
            end
          end
          door_construction = default_sub_surface_construction_set.doorConstruction
          if !door_construction.empty?
            if door_construction.get.name.to_s == old_construction.name.to_s
              default_sub_surface_construction_set.setDoorConstruction(new_construction.to_ConstructionBase.get)
              num_swaps += 1
            end
          end
          glass_door_construction = default_sub_surface_construction_set.glassDoorConstruction
          if !glass_door_construction.empty?
            if glass_door_construction.get.name.to_s == old_construction.name.to_s
              default_sub_surface_construction_set.setGlassDoorConstruction(new_construction.to_ConstructionBase.get)
              num_swaps += 1
            end
          end
          overhead_construction = default_sub_surface_construction_set.overheadDoorConstruction
          if !overhead_construction.empty?
            if overhead_construction.get.name.to_s == old_construction.name.to_s
              default_sub_surface_construction_set.setOverheadDoorConstruction(new_construction.to_ConstructionBase.get)
              num_swaps += 1
            end
          end
          skylight_construction = default_sub_surface_construction_set.skylightConstruction
          if !skylight_construction.empty?
            if skylight_construction.get.name.to_s == old_construction.name.to_s
              default_sub_surface_construction_set.setSkylightConstruction(new_construction.to_ConstructionBase.get)
              num_swaps += 1
            end
          end
          daylight_dome_construction = default_sub_surface_construction_set.tubularDaylightDomeConstruction
          if !daylight_dome_construction.empty?
            if daylight_dome_construction.get.name.to_s == old_construction.name.to_s
              default_sub_surface_construction_set.setTubularDaylightDomeConstruction(new_construction.to_ConstructionBase.get)
              num_swaps += 1
            end
          end
          daylight_diffuser_construction = default_sub_surface_construction_set.tubularDaylightDiffuserConstruction
          if !daylight_diffuser_construction.empty?
            if daylight_diffuser_construction.get.name.to_s == old_construction.name.to_s
              default_sub_surface_construction_set.setTubularDaylightDiffuserConstruction(new_construction.to_ConstructionBase.get)
              num_swaps += 1
            end
          end
        end
      end

      if !default_int_partition_const.empty?
        if default_int_partition_const.get.name.to_s == old_construction.name.to_s
          default_construction_set.setInteriorPartitionConstruction(new_construction.to_ConstructionBase.get)
          num_swaps += 1
        end
      end
      
      if !default_space_shade_const.empty?
        if default_space_shade_const.get.name.to_s == old_construction.name.to_s
          default_construction_set.setSpaceShadingConstruction(new_construction.to_ConstructionBase.get)
          num_swaps += 1
        end
      end
      
      if !default_bldg_shade_const.empty?
        if default_bldg_shade_const.get.name.to_s == old_construction.name.to_s
          default_construction_set.setBuildingShadingConstruction(new_construction.to_ConstructionBase.get)
          num_swaps += 1
        end
      end
      
      if !default_site_shade_const.empty?
        if default_site_shade_const.get.name.to_s == old_construction.name.to_s
          default_construction_set.setSiteShadingConstruction(new_construction.to_ConstructionBase.get)
          num_swaps += 1
        end
      end
    end # end of loop through default_construction_sets
    
    runner.registerFinalCondition("#{num_swaps} substitutions were made in the model.")
   
    return true

  end # end the run method

end # end the measure

# this allows the measure to be use by the application
SwapConstructionInConstructionSet.new.registerWithApplication