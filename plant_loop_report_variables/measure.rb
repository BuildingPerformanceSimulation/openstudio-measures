# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'erb'

#start the measure
class PlantLoopReportVariables < OpenStudio::Ruleset::ReportingUserScript

  # human readable name
  def name
    return "Plant Loop Report Variables"
  end

  # human readable description
  def description
    return "Adds a bunch of output variables that are useful for debugging plantloop operation.  Does not create a report."
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # this measure does not require any user arguments, return an empty list

    return args
  end 
  
  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)
    
    result = OpenStudio::IdfObjectVector.new
    
    # use the built-in error checking 
    if !runner.validateUserArguments(arguments(), user_arguments)
      return result
    end
    
    reporting_frequency = "timestep"
    out_var_names = []
    
    # Outdoor air
    out_var_names << "Site Outdoor Air Drybulb Temperature"
    out_var_names << "Site Outdoor Air Wetbulb Temperature"
    
    # Heat exchanger
    out_var_names << "Fluid Heat Exchanger Heat Transfer Rate"
    out_var_names << "Fluid Heat Exchanger Heat Transfer Energy"
    out_var_names << "Fluid Heat Exchanger Loop Supply Side Mass Flow Rate"
    out_var_names << "Fluid Heat Exchanger Loop Supply Side Inlet Temperature"
    out_var_names << "Fluid Heat Exchanger Loop Supply Side Outlet Temperature"
    out_var_names << "Fluid Heat Exchanger Loop Demand Side Mass Flow Rate"
    out_var_names << "Fluid Heat Exchanger Loop Demand Side Inlet Temperature"
    out_var_names << "Fluid Heat Exchanger Loop Demand Side Outlet Temperature"
    out_var_names << "Fluid Heat Exchanger Operation Status"
    out_var_names << "Fluid Heat Exchanger Effectiveness"

    # Boilers
    out_var_names << "Boiler Part Load Ratio"
    out_var_names << "Boiler Gas Rate"
    out_var_names << "Boiler Heating Rate"
    out_var_names << "Boiler Inlet Temperature"
    out_var_names << "Boiler Outlet Temperature"
    out_var_names << "Boiler Mass Flow Rate"
    out_var_names << "Boiler Ancillary Electric Power"
    
    # Water Heaters
    out_var_names << "Water Heater Use Side Mass Flow Rate"
    out_var_names << "Water Heater Use Side Inlet Temperature"
    out_var_names << "Water Heater Use Side Outlet Temperature"
    out_var_names << "Water Heater Use Side Heat Transfer Rate"
    out_var_names << "Water Heater Tank Temperature"
    out_var_names << "Water Heater Source Side Mass Flow Rate"
    out_var_names << "Water Heater Source Side Inlet Temperature"
    out_var_names << "Water Heater Source Side Outlet Temperature"    
    out_var_names << "Water Heater Source Side Heat Transfer Rate"    
    out_var_names << "Water Heater Total Demand Heat Transfer Rate"    
    out_var_names << "Water Heater Heating Rate"
    out_var_names << "Water Heater Water Volume Flow Rate"
    
    # Chillers
    out_var_names << "Chiller Part Load Ratio"
    out_var_names << "Chiller Cycling Ratio"
    out_var_names << "Chiller Electric Power"
    out_var_names << "Chiller COP"
    out_var_names << "Chiller Evaporator Mass Flow Rate"
    out_var_names << "Chiller Evaporator Cooling Rate"
    out_var_names << "Chiller Evaporator Inlet Temperature"
    out_var_names << "Chiller Evaporator Outlet Temperature"
    out_var_names << "Chiller Condenser Mass Flow Rate"
    out_var_names << "Chiller Condenser Heat Transfer Rate"
    out_var_names << "Chiller Condenser Inlet Temperature"
    out_var_names << "Chiller Condenser Outlet Temperature"

    # Chiller Heat Recovery
    out_var_names << "Chiller Total Recovered Heat Rate"
    out_var_names << "Chiller Heat Recovery Inlet Temperature"
    out_var_names << "Chiller Heat Recovery Outlet Temperature"
    out_var_names << "Chiller Heat Recovery Mass Flow Rate"
    out_var_names << "Chiller Effective Heat Rejection Temperature"

    # Pump
    out_var_names << "Pump Mass Flow Rate"
    out_var_names << "Pump Fluid Heat Gain Rate"
    out_var_names << "Pump Electric Power"
    
    # Plant
    out_var_names << "Plant Supply Side Cooling Demand Rate"
    out_var_names << "Plant Supply Side Unmet Demand Rate"
    out_var_names << "Debug Plant Loop Bypass Fraction"
    out_var_names << "Plant Supply Side Inlet Temperature"
    out_var_names << "Plant Supply Side Outlet Temperature"
    out_var_names << "Plant Common Pipe Mass Flow Rate"
    
    # Cooling Tower
    out_var_names << "Cooling Tower Heat Transfer Rate"
    out_var_names << "Cooling Tower Fan Electric Power"
    out_var_names << "Cooling Tower Operating Cells Count"
    
    # Load Profile
    out_var_names << "Plant Load Profile Mass Flow Rate"
    out_var_names << "Plant Load Profile Heat Transfer Rate"
    out_var_names << "Plant Load Profile Heating Energy"  
    out_var_names << "Plant Load Profile Cooling Energy"
    out_var_names << "Cooling Tower Operating Cells Count"  
    
    # Request the variables
    out_var_names.each do |out_var_name|
      request = OpenStudio::IdfObject.load("Output:Variable,*,#{out_var_name},#{reporting_frequency};").get
      result << request
      runner.registerInfo("Adding output variable for '#{out_var_name}' reporting #{reporting_frequency}")
    end
    
    return result
  end
  
  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking 
    if !runner.validateUserArguments(arguments(), user_arguments)
      return false
    end

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get

    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)

    web_asset_path = OpenStudio.getSharedResourcesPath() / OpenStudio::Path.new("web_assets")

    # close the sql file
    sqlFile.close()

    return true
 
  end

end

# register the measure to be used by the application
PlantLoopReportVariables.new.registerWithApplication
