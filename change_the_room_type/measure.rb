# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class ChangeTheRoomType < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "ChangeTheRoomType"
  end

  # human readable description
  def description
    return "Take stratification into account"
  end

  # human readable description of modeling approach
  def modeler_description
    return "By changing the room type to constant gradient (vertical)"
  end

  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #----------------------THERMAL ZONE INTO ARGUMENTS------------------------------------------
    # get all thermal zones in the starting model
    zone_display_names = OpenStudio::StringVector.new
    zones = workspace.getObjectsByType("Zone".to_IddObjectType)
    zones.each do |zone|
      zone_display_names << zone.getString(0).get
    end

    #make an argument for zones
    zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("zone", zone_display_names, true)
    zone.setDisplayName("Choose Thermal Zones to add zone ventilation to.")
    args << zone

    #made this as string arg so I didn't have to check different kinds of schedule objects.
    # todo - in future update to choice argument that includes all schedule types
    availSchRoomAirModel = OpenStudio::Ruleset::OSArgument::makeStringArgument('availSchRoomAirModel', true)
    availSchRoomAirModel.setDisplayName('Availability Schedule Name')
    args << availSchRoomAirModel

    #made this as string arg so I didn't have to check different kinds of schedule objects.
    # todo - in future update to choice argument that includes all schedule types
    patCtrlSchRoomAirModel = OpenStudio::Ruleset::OSArgument::makeStringArgument('patCtrlSchRoomAirModel', true)
    patCtrlSchRoomAirModel.setDisplayName('Pattern Control Schedule Name')
    args << patCtrlSchRoomAirModel

    #----------------------------NAME ARGUMENT------------------------------------------
    nameRoomAirModel = OpenStudio::Ruleset::OSArgument::makeStringArgument('nameRoomAirModel', true)
    nameRoomAirModel.setDisplayName('Name the pattern')
    args << nameRoomAirModel

    #-------------------------------TEMPERATURE INPUT INTO ARGUMENTS -------------------------------
    thermOffset = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('thermOffset',true)
    thermOffset.setDisplayName('thermostat Offset')
    thermOffset.setDefaultValue(0.0)
    args << thermOffset

    returnAirOffset = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('returnAirOffset',true)
    returnAirOffset.setDisplayName('return Air Offset')
    returnAirOffset.setDefaultValue(0.0)
    args<<returnAirOffset

    exhaustAirOffset = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('exhaustAirOffset',true)
    exhaustAirOffset.setDisplayName('exhaust Air Offset')
    exhaustAirOffset.setDefaultValue(0.0)
    args << exhaustAirOffset

    return args
  end

  #When the measure is run
  def run(workspace,runner,user_arguments)
    super(workspace, runner, user_arguments)

    # errors management
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    #assign to variables
    nameRoomAirModel=runner.getStringArgumentValue('nameRoomAirModel',user_arguments)
    availSchRoomAirModel=runner.getStringArgumentValue('availSchRoomAirModel',user_arguments)
    patCtrlSchRoomAirModel=runner.getStringArgumentValue('patCtrlSchRoomAirModel',user_arguments)
    zone=runner.getStringArgumentValue('zone',user_arguments)
    thermOffset=runner.getDoubleArgumentValue('thermOffset', user_arguments)
    returnAirOffset=runner.getDoubleArgumentValue('returnAirOffset',user_arguments)
    exhaustAirOffset=runner.getDoubleArgumentValue('exhaustAirOffset',user_arguments)

    # todo - availability schedule
    # todo - patern control schedule name

    #string_RoomAirModelType
    string_RoomAirModelType = "
    RoomAir:TemperaturePattern:UserDefined,
    #{nameRoomAirModel.to_s} ,   ! Name
    #{zone.to_s} ,               ! Zone Name (thermal zone) = user choice
    #{availSchRoomAirModel},     ! Availability Schedule Name = integer used need to be the same as the RoomAir:TemperaturePattern:ConstantGradient (here is 1)
    #{patCtrlSchRoomAirModel};   ! Pattern Control Schedule Name"

    #string_RoomAirModelGradient
    string_RoomAirModelGradient = "
    RoomAir:TemperaturePattern:ConstantGradient,
    StratProduction,        !- Name
    1,                      !- Control Integer for Pattern Control Schedule Name
    #{thermOffset},         !- Thermostat Offset {deltaC}
    #{returnAirOffset} ,    !- Return Air Offset {deltaC}
    #{exhaustAirOffset} ,   !- Exhaust Air Offset {deltaC}
    0.5;                    !- Temperature Gradient {K/m}"

    #add all of the strings to workspace to create IDF objects
    idfObject = OpenStudio::IdfObject::load(string_RoomAirModelType)
    object = idfObject.get
    wsObject = workspace.addObject(object)
    new_object = wsObject.get
    runner.registerInfo("An object named '#{new_object.getString(0)}' was added.")

    idfObject = OpenStudio::IdfObject::load(string_RoomAirModelGradient)
    object = idfObject.get
    wsObject = workspace.addObject(object)
    new_object = wsObject.get
    runner.registerInfo("An object named '#{new_object.getString(0)}' was added.")

    return true
  end

end

# register the measure to be used by the application
ChangeTheRoomType.new.registerWithApplication