class AddWatersideEconomizer < OpenStudio::Ruleset::ModelUserScript
  
  def name
    return "Add Waterside Economizer"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
	
    #select plant loops
    plantLoops = model.getPlantLoops
    plantLoops_handle = OpenStudio::StringVector.new
    plantLoops_displayName = OpenStudio::StringVector.new
    plantLoops.each do |plantLoop|
      plantLoops_handle << plantLoop.handle.to_s
      plantLoops_displayName << plantLoop.name.to_s
    end
    
    #make an argument for heating loop, if applicable
    condenser_water_loop = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("condenser_water_loop", plantLoops_handle, plantLoops_displayName,false)
    condenser_water_loop.setDisplayName("Select the condenser water loop:")
    args << condenser_water_loop
    
    #make an argument for cooling loop, if applicable
    chilled_water_loop = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("chilled_water_loop", plantLoops_handle, plantLoops_displayName,false)
    chilled_water_loop.setDisplayName("Select the chilled water loop:")
    args << chilled_water_loop    
		
    return args
  end #end the arguments method
  
  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    condenser_water_loop = runner.getOptionalWorkspaceObjectChoiceValue("condenser_water_loop",user_arguments,model)
    chilled_water_loop = runner.getOptionalWorkspaceObjectChoiceValue("chilled_water_loop",user_arguments,model)
    
    #check the condenser_water_loop for reasonableness
    if condenser_water_loop.empty?
      runner.registerError("The selected plant loop was not found in the model. It may have been removed by another measure.")
      return false
    else
      if not condenser_water_loop.get.to_PlantLoop.empty?
        condenser_water_loop = condenser_water_loop.get.to_PlantLoop.get
        runner.registerInfo("Using plant loop #{condenser_water_loop.name.to_s} as condenser water loop.")
      else
        runner.registerError("Script Error - argument not showing up as plant loop.")
        return false
      end
    end
    
    #check the chilled_water_loop for reasonableness
    if chilled_water_loop.empty?
        runner.registerError("The selected plant loop was not found in the model. It may have been removed by another measure.")
        return false
    else
      if not chilled_water_loop.get.to_PlantLoop.empty?
        chilled_water_loop = chilled_water_loop.get.to_PlantLoop.get
        runner.registerInfo("Using plant loop #{chilled_water_loop.name.to_s} as chilled water loop.")
      else
        runner.registerError("Script Error - argument not showing up as plant loop.")
        return false
      end
    end
    
    #make new heat exchanger
    heat_exchanger = OpenStudio::Model::HeatExchangerFluidToFluid.new(model)
    heat_exchanger.setName("Waterside Economizer Heat Exchanger")
    heat_exchanger.setHeatExchangeModelType("Ideal")
    heat_exchanger.setControlType("CoolingSetpointOnOff")
    heat_exchanger.setMinimumTemperatureDifferencetoActivateHeatExchanger(OpenStudio.convert(4,"R","K").get)
    heat_exchanger.setHeatTransferMeteringEndUseType("FreeCooling")
    heat_exchanger.setOperationMinimumTemperatureLimit(OpenStudio.convert(35,"F","C").get)
    heat_exchanger.setOperationMaximumTemperatureLimit(OpenStudio.convert(72,"F","C").get)
    
    #add heat exchanger to condenser water loop
    condenser_water_loop.addDemandBranchForComponent(heat_exchanger)

    #add heat exchanger to chilled water loop
    chilled_water_loop_supply_inlet_node = chilled_water_loop.supplyInletNode
    heat_exchanger.addToNode(chilled_water_loop_supply_inlet_node)
    
    runner.registerFinalCondition("Added #{heat_exchanger.name.to_s} to condenser water loop #{condenser_water_loop.name.to_s} and chilled water loop #{chilled_water_loop.name.to_s}.")
    
    return true
  
  end #end the run method
end #end the measure

#this allows the measure to be use by the application
AddWatersideEconomizer.new.registerWithApplication