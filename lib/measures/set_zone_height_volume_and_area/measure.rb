# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class SetZoneHeightVolumeAndArea < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Set Zone Height Volume and Area"
  end

  # human readable description
  def description
    return "This coudl be used anytime you want to overwrite the calculated values, but it was specifically designe for pinwheel model where there only exterior surfaces associated to the thermal zones. "
  end

  # human readable description of modeling approach
  def modeler_description
    return "Setting ceiling height and floor area is pretty straight forward using API methods. While floor area is stored in the OSM, there isn't a method expsoed to set it, so setString is used."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument for thermal zones in the model
    zone_handles = OpenStudio::StringVector.new
    zone_display_names = OpenStudio::StringVector.new

    #putting zone names into hash
    zone_hash = {}
    model.getThermalZones.each do |zone|
      zone_hash[zone.name.to_s] = zone
    end

    #looping through sorted hash of zones
    zone_hash.sort.map do |zone_name, zone|
      zone_handles << zone.handle.to_s
      zone_display_names << zone_name
    end

    #make an argument for zones
    zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("zone", zone_handles, zone_display_names, true)
    zone.setDisplayName("Choose Thermal Zones to alter.")
    args << zone

    # todo - make each argument below optional

    # ceiling_height
    ceiling_height = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("ceiling_height", true)
    ceiling_height.setDisplayName("Ceiling Height")
    ceiling_height.setDescription("The requested zone ceiling height will override model geometry. Zone multiplier will still apply to this.")
    ceiling_height.setUnits('ft')
    args << ceiling_height

    # volume
    volume = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("volume", true)
    volume.setDisplayName("Volume")
    volume.setDescription("The requested zone volume will override model geometry. Zone multiplier will still apply to this.")
    volume.setUnits('ft^3')
    args << volume

    # floor_area
    floor_area = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("floor_area", true)
    floor_area.setDisplayName("Floor Area")
    floor_area.setDescription("This requested zone floor area will override model geometry. Zone multiplier will still apply to this.")
    floor_area.setUnits('ft^2')
    args << floor_area

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
    zone = runner.getOptionalWorkspaceObjectChoiceValue("zone",user_arguments,model) #model is passed in because of argument type
    ceiling_height = runner.getDoubleArgumentValue("ceiling_height",user_arguments)
    volume = runner.getDoubleArgumentValue("volume",user_arguments)
    floor_area = runner.getDoubleArgumentValue("floor_area",user_arguments)

    if not zone.get.to_ThermalZone.empty?
      zone = zone.get.to_ThermalZone.get
    else
      runner.registerError("Script Error - argument not showing up as thermal zone.")
      return false
    end

    # todo - check for non negative values

    # check for hard assigned zone areas
    zones_with_custom_floor_area = []
    model.getThermalZones.each do |zone|
      if zone.getString(5).is_initialized
        zones_with_custom_floor_area << zone
      end
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{zones_with_custom_floor_area.size} zones with custom floor area.")

    # set zone properties
    zone.setCeilingHeight(OpenStudio.convert(ceiling_height,'ft','m').get)
    zone.setVolume(OpenStudio.convert(volume,'ft^3','m^3').get)
    zone.setString(5,OpenStudio.convert(floor_area,'ft^2','m^2').get.to_s) # no method in OS 1.14.0 so using setString
    runner.registerInfo("Setting height, volume, and floor area for #{zone.name}")

    # check for hard assigned zone areas
    zones_with_custom_floor_area = []
    model.getThermalZones.each do |zone|
      if zone.getString(5).is_initialized
        zones_with_custom_floor_area << zone
      end
    end
    
    # report final condition of model
    runner.registerFinalCondition("The building finished with #{zones_with_custom_floor_area.size} zones with custom floor area.")

    return true

  end
  
end

# register the measure to be used by the application
SetZoneHeightVolumeAndArea.new.registerWithApplication
