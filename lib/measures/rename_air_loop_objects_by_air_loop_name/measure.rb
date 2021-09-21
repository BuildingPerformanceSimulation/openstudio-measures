class RenameAirLoopObjectsByAirLoopName < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Rename Air Loop Objects By Air Loop Name"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    # No measure arguments.  Could add arguments to customize naming logic.
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #reporting initial condition of model
    air_loops = model.getAirLoopHVACs
    runner.registerInitialCondition("The building has #{air_loops.size} air loops.")

    setpoint_managers = model.getSetpointManagers
    
    counter = 0  
    air_loops.each do |air_loop|
      counter += 1
      
      # rename nodes
      air_loop_name = air_loop.name.to_s
      air_loop.demandInletNode.setName("#{air_loop_name} Demand Inlet Node")
      air_loop.demandOutletNode.setName("#{air_loop_name} Demand Outlet Node")
      air_loop.supplyInletNode.setName("#{air_loop_name} Supply Inlet Node")
      air_loop.supplyOutletNode.setName("#{air_loop_name} Supply Outlet Node")

      relief_node = air_loop.reliefAirNode
      if !relief_node.empty?
        relief_node = relief_node.get
        relief_node.setName("#{air_loop_name} Relief Air Node")
      end

      mixed_node = air_loop.mixedAirNode
      if !mixed_node.empty?
        mixed_node = mixed_node.get
        mixed_node.setName("#{air_loop_name} Mixed Air Node")
      end

      # rename outdoor air system and nodes
      oa_system = air_loop.airLoopHVACOutdoorAirSystem
      if !oa_system.empty?
        oa_system = oa_system.get
        oa_system.setName("#{air_loop_name} Outdoor Air System")
        oa_controller = oa_system.getControllerOutdoorAir
        oa_controller.setName("#{air_loop_name} Controller Outdoor Air")
        oa_node = oa_system.outboardOANode
        if !oa_node.empty?
          oa_node = oa_node.get
          oa_node.setName("#{air_loop_name} Outdoor Air Node")
        end  
      end

      # rename supply fan
      supply_fan = air_loop.supplyFan
      if !supply_fan.empty?
        supply_fan = supply_fan.get
        if !supply_fan.to_FanVariableVolume.empty?
          supply_fan.setName("#{air_loop_name} Supply Fan Variable Volume")
        elsif !supply_fan.to_FanConstantVolume.empty?
          supply_fan.setName("#{air_loop_name} Supply Fan Constant Volume")
        elsif !supply_fan.to_FanOnOff.empty?
          supply_fan.setName("#{air_loop_name} Supply Fan On Off")
        else
          supply_fan.setName("#{air_loop_name} Supply Fan")
        end
      end
      
      # rename relief fan
      relief_fan = air_loop.reliefFan
      if !relief_fan.empty?
        relief_fan = relief_fan.get
        if !relief_fan.to_FanVariableVolume.empty?
          relief_fan.setName("#{air_loop_name} Relief Fan Variable Volume")
        elsif !relief_fan.to_FanConstantVolume.empty?
          relief_fan.setName("#{air_loop_name} Relief Fan Constant Volume")
        elsif !relief_fan.to_FanOnOff.empty?
          relief_fan.setName("#{air_loop_name} Relief Fan On Off")
        else
          relief_fan.setName("#{air_loop_name} Relief Fan")
        end
      end
      
      # rename return fan
      return_fan = air_loop.returnFan
      if !return_fan.empty?
        return_fan = return_fan.get
        if !return_fan.to_FanVariableVolume.empty?
          return_fan.setName("#{air_loop_name} Return Fan Variable Volume")
        elsif !return_fan.to_FanConstantVolume.empty?
          return_fan.setName("#{air_loop_name} Return Fan Constant Volume")
        elsif !return_fan.to_FanOnOff.empty?
          return_fan.setName("#{air_loop_name} Return Fan On Off")
        else
          return_fan.setName("#{air_loop_name} Return Fan")
        end
      end
      
      # rename setpoint manager
      setpoint_managers.each do |setpoint_manager|
        if
          air_loop_hvac = setpoint_manager.airLoopHVAC
          if !air_loop_hvac.empty?
            if air_loop_hvac.get.name.to_s == air_loop_name
              setpoint_manager.setName("#{air_loop_name} Setpoint Manager")
            end
          end
        end
      end
      
      # TODO: add logic to rename coils, coil inlet/outlet nodes, and coil controllers if applicable 
      
    end # end air_loops.each
    
    # rename demand side nodes
    model.getThermalZones.each do |zone|
      zone.zoneAirNode.setName("#{zone.name.to_s} Zone Air Node")
      if !zone.airLoopHVACTerminal.empty?
        terminal_unit = zone.airLoopHVACTerminal.get
        if !terminal_unit.to_StraightComponent.nil?
          component = terminal_unit.to_StraightComponent.get
          component.inletModelObject.get.setName("#{terminal_unit.name.to_s} Inlet Air Node")
          component.outletModelObject.get.setName("#{zone.name.to_s} Supply Air Node")
        end
      end
      
      if !zone.returnAirModelObject.empty?
        zone.returnAirModelObject.get.setName("#{zone.name.to_s} Return Air Node")
      end
    end

    #reporting final condition of model
    runner.registerFinalCondition("All node, fan, and outdoor air system objects on air loops have been renamed.")
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
RenameAirLoopObjectsByAirLoopName.new.registerWithApplication