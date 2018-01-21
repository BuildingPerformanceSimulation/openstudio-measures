#start the measure
class ChangeFanVariableVolumeCoefficients < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Change Variable Volume Fan Coefficients"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #populate choice argument
    fans = model.getFanVariableVolumes
    fan_handles = OpenStudio::StringVector.new
    fan_display_names = OpenStudio::StringVector.new

    #loop through fans and add to handles
    fan_handles << OpenStudio::toUUID("").to_s
    fan_display_names << "*All Variable Volume Fans*"
    fans.each do |fan|
      fan_handles << fan.handle.to_s
      fan_display_names << fan.name.to_s
    end

    #make an argument for air fans
    fan_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("fan_choice", fan_handles, fan_display_names,true)
    fan_choice.setDisplayName("Choose an Variable Volume Fan to change coefficients.")
    fan_choice.setDefaultValue("*All Variable Volume Fans*") #if no fan is chosen this will run on all air fans
    args << fan_choice

    #make an argument to choose which coefficients to use
    coeff_choices = OpenStudio::StringVector.new
    coeff_choices << "Multi Zone VAV with Airfoil or Backward Incline riding the curve"
    coeff_choices << "Multi Zone VAV with Airfoil or Backward Incline with inlet vanes"
    coeff_choices << "Multi Zone VAV with Forward Curved fans riding the curve"
    coeff_choices << "Multi Zone VAV with Forward Curved with inlet vanes"
    coeff_choices << "Multi Zone VAV with vane-axial with variable pitch blades"
    coeff_choices << "Multi Zone VAV with VSD and fixed SP setpoint"
    coeff_choices << "Multi zone VAV with static pressure reset"
    coeff_choices << "Single zone VAV fan"
    coeff_choices << "Typical VSD Fan"
    coeff_choices << "No SP Reset VSD Fan"
    coeff_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("coeff_choice", coeff_choices, true)
    coeff_choice.setDisplayName("Choose fan coefficient set to use:")
    coeff_choice.setDefaultValue("Multi zone VAV with static pressure reset")
    coeff_choice.setDescription("The OpenStudio default is *Multi zone VAV with static pressure reset* and assumes a good static pressure reset.  This is the ASHRAE 90.1 PRM baseline for systems 5-8.  The ASHRAE 90.1 PRM baseline for system 11 is *Single zone VAV fan* representing a perfect static pressure reset.  The ASHRAE 90.1 App.G baseline is *Multi Zone VAV with VSD and fixed SP setpoint*.  See resources folder in measure for more information.")
    args << coeff_choice
    
    return args
  end #end the arguments method

  #define what happens when the measure is cop
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    fan_choice = runner.getOptionalWorkspaceObjectChoiceValue("fan_choice",user_arguments,model) #model is passed in because of argument type
    coeff_choice = runner.getOptionalStringArgumentValue("coeff_choice", user_arguments)
    
    #check the fan for reasonableness
    apply_to_all_fans = false
    fan = nil
    if fan_choice.empty?
      handle = runner.getStringArgumentValue("fan_choice",user_arguments)
      if handle == OpenStudio::toUUID("").to_s
        #all fans
        apply_to_all_fans = true
        fan = nil
        runner.registerInfo("Apply new coefficients to all variable volume fans.")
      else
        runner.registerError("The selected fan with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        return false
      end
    else
      if not fan_choice.get.to_FanVariableVolume.empty?
        fan = fan_choice.get.to_FanVariableVolume.get
      else
        runner.registerError("Script Error - argument not showing up as a Fan Variable Volume.")
        return false
      end
    end  #end of if fan.empty?

    #get fans for measure
    if apply_to_all_fans
      fans = model.getFanVariableVolumes
    else
      fans = []
      fans << fan
    end
    
    if fans.size == 0
      runner.registerError("Measure not applicable because there are no variable volume fans in the model.")
    end
    
    #loop through fans and set new coefficients
    num_fans = 0
    fans.each do |fan|
      if coeff_choice.to_s == "Multi Zone VAV with Airfoil or Backward Incline riding the curve"
        runner.registerInfo("Setting #{fan.name.to_s} coefficients to Multi Zone VAV with Airfoil or Backward Incline riding the curve")
        fan.setFanPowerCoefficient1(0.1631)
        fan.setFanPowerCoefficient2(1.5901)
        fan.setFanPowerCoefficient3(-0.8817)
        fan.setFanPowerCoefficient4(0.1281)
        fan.setFanPowerMinimumFlowFraction(0.70)
      elsif coeff_choice.to_s == "Multi Zone VAV with Airfoil or Backward Incline with inlet vanes"
        runner.registerInfo("Setting #{fan.name.to_s} coefficients to Multi Zone VAV with Airfoil or Backward Incline with inlet vanes")
        fan.setFanPowerCoefficient1(0.9977)
        fan.setFanPowerCoefficient2(-0.659)
        fan.setFanPowerCoefficient3(0.9547)
        fan.setFanPowerCoefficient4(-0.2936)
        fan.setFanPowerMinimumFlowFraction(0.50)
      elsif coeff_choice.to_s == "Multi Zone VAV with Forward Curved fans riding the curve"
        runner.registerInfo("Setting #{fan.name.to_s} coefficients to Multi Zone VAV with Forward Curved fans riding the curve")
        fan.setFanPowerCoefficient1(0.1224)
        fan.setFanPowerCoefficient2(0.612)
        fan.setFanPowerCoefficient3(0.5983)
        fan.setFanPowerCoefficient4(-0.3334)
        fan.setFanPowerMinimumFlowFraction(0.30)
      elsif coeff_choice.to_s == "Multi Zone VAV with Forward Curved with inlet vanes"
        runner.registerInfo("Setting #{fan.name.to_s} coefficients to Multi Zone VAV with Forward Curved with inlet vanes")
        fan.setFanPowerCoefficient1(0.3038)
        fan.setFanPowerCoefficient2(-0.7608)
        fan.setFanPowerCoefficient3(2.2729)
        fan.setFanPowerCoefficient4(-0.8169)
        fan.setFanPowerMinimumFlowFraction(0.30)
      elsif coeff_choice.to_s == "Multi Zone VAV with vane-axial with variable pitch blades"
        runner.registerInfo("Setting #{fan.name.to_s} coefficients to Multi Zone VAV with vane-axial with variable pitch blades")
        fan.setFanPowerCoefficient1(0.1639)
        fan.setFanPowerCoefficient2(-0.4016)
        fan.setFanPowerCoefficient3(1.9909)
        fan.setFanPowerCoefficient4(-0.7541)
        fan.setFanPowerMinimumFlowFraction(0.20)        
      elsif coeff_choice.to_s == "Multi Zone VAV with VSD and fixed SP setpoint"
        runner.registerInfo("Setting #{fan.name.to_s} coefficients to Multi Zone VAV with VSD and fixed SP setpoint")
        fan.setFanPowerCoefficient1(0.0013)
        fan.setFanPowerCoefficient2(0.1470)
        fan.setFanPowerCoefficient3(0.9506)
        fan.setFanPowerCoefficient4(-0.0998)
        fan.setFanPowerMinimumFlowFraction(0.20)
      elsif coeff_choice.to_s == "Multi zone VAV with static pressure reset"
        runner.registerInfo("setting #{fan.name.to_s} coefficients to Multi zone VAV with static pressure reset")
        fan.setFanPowerCoefficient1(0.040759894)
        fan.setFanPowerCoefficient2(0.088044970)
        fan.setFanPowerCoefficient3(-0.072926120)
        fan.setFanPowerCoefficient4(0.943739823)
        fan.setFanPowerMinimumFlowFraction(0.10)
      elsif coeff_choice.to_s == "Single zone VAV fan"
        runner.registerInfo("Setting #{fan.name.to_s} coefficients to Single zone VAV fan")
        fan.setFanPowerCoefficient1(0.027827882)
        fan.setFanPowerCoefficient2(0.026583195)
        fan.setFanPowerCoefficient3(-0.0870687)
        fan.setFanPowerCoefficient4(1.03091975)
        fan.setFanPowerMinimumFlowFraction(0.10)
      elsif coeff_choice.to_s == "Typical VSD Fan"
      runner.registerInfo("Setting #{fan.name.to_s} coefficients to Typical VSD Fan")
        fan.setFanPowerCoefficient1(0.047182815)
        fan.setFanPowerCoefficient2(0.130541742)
        fan.setFanPowerCoefficient3(-0.117286942)
        fan.setFanPowerCoefficient4(0.940313747)
        fan.setFanPowerMinimumFlowFraction(0.10)
      elsif coeff_choice.to_s == "No SP Reset VSD Fan"
        runner.registerInfo("Setting #{fan.name.to_s} coefficients to No SP Reset VSD Fan")
        fan.setFanPowerCoefficient1(0.070428852)
        fan.setFanPowerCoefficient2(0.385330201)
        fan.setFanPowerCoefficient3(-0.460864118)
        fan.setFanPowerCoefficient4(1.00920344)
        fan.setFanPowerMinimumFlowFraction(0.10)
      end
      num_fans += 1      
	  end
    
    runner.registerFinalCondition("Changed fan coefficients for #{num_fans} fan object(s) to #{coeff_choice}")	
    return true

  end #end run definition

end #end the measure

#this allows the measure to be used by the application
ChangeFanVariableVolumeCoefficients.new.registerWithApplication