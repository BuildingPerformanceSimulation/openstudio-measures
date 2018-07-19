class SetOutputTableToIPunits < OpenStudio::Ruleset::WorkspaceUserScript

  def name
    return "Set Output Table To IP Units"
  end

  def description
	  return "This measure changes the output table to be in IP units"
  end
  
  #define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    #if IP units requested add OutputControl:Table:Style object
    table_style = workspace.getObjectsByType("OutputControl:Table:Style".to_IddObjectType)
    
    #even though there is just a single object, it is still in an array
    if not table_style.empty?
      #we can access the first object in the array using the table_style[0]
      #use setString to change the field value to request IP units
      table_style_ip = table_style[0].setString(1,"InchPound")
    end
    return true
  end #end the run method
end #end the measure
	

#this allows the measure to be use by the application
SetOutputTableToIPunits.new.registerWithApplication