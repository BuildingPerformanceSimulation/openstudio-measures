require 'erb'
require 'json'

# start the measure
class DetailedHVACViewer < OpenStudio::Measure::ReportingMeasure

  # human readable name
  def name
    return "Detailed HVAC Viewer"
  end

  # human readable description
  def description
    return 'This measure creates a facsimile of the HVAC grid layout in the OpenStudio Application in an interactive html report. The user can optionally select loops to add Output:Variable to view node timeseries output data.'
  end

  # human readable description of modeling approach
  def modeler_description
    return "The user is asked to provided the following parameters:
- A plantLoop or airLoop from the model (dropdown)
- A boolean to include or exclude demand nodes
- Which variable they want to output for each node:
    * System Node Temperature
    * System Node Setpoint Temperature
    * System Node Mass Flow Rate
    * etc."
  end

  # define the arguments that the user will input
  def arguments(model=nil)
    args = OpenStudio::Measure::OSArgumentVector.new

    # include demand side nodes
    include_demand_nodes = OpenStudio::Measure::OSArgument::makeBoolArgument('include_demand_nodes',true)
    include_demand_nodes.setDisplayName('Include Demand Side nodes in the timeseries output?')
    include_demand_nodes.setDefaultValue(false)
    args << include_demand_nodes

    chs = OpenStudio::StringVector.new
    chs << 'Detailed'
    chs << 'Timestep'
    chs << 'Hourly'
    chs << 'Daily'
    chs << 'Monthly'
    reporting_frequency = OpenStudio::Measure::OSArgument::makeChoiceArgument('reporting_frequency', chs, true)
    reporting_frequency.setDisplayName("<h3>Select a Reporting Frequency?</h3>")
    reporting_frequency.setDefaultValue("Hourly")
    args << reporting_frequency

    # reporting variables
    var_hash = {
      'System Node Temperature' => true,
      'System Node Setpoint Temperature' => false,
      'System Node Mass Flow Rate' => true,
      'System Node Humidity Ratio' => false,
      'System Node Setpoint High Temperature' => false,
      'System Node Setpoint Low Temperature' => false,
      'System Node Setpoint Humidity Ratio' => false,
      'System Node Setpoint Minimum Humidity Ratio' => false,
      'System Node Setpoint Maximum Humidity Ratio' => false,
      'System Node Relative Humidity' => false,
      'System Node Pressure' => false,
      'System Node Standard Density Volume Flow Rate' => false,
      'System Node Current Density Volume Flow Rate' => false,
      'System Node Current Density' => false,
      'System Node Enthalpy' => false,
      'System Node Wetbulb Temperature' => false,
      'System Node Dewpoint Temperature' => false,
      'System Node Quality' => false,
      'System Node Height' => false
    }

    var_hash.each do |k, v|
      new_arg = OpenStudio::Measure::OSArgument::makeBoolArgument(k, true)
      new_arg.setDisplayName(k)
      new_arg.setDefaultValue(v)
      args << new_arg
    end
    return args
  end

  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  # Warning: Do not change the name of this method to be snake_case. The method must be lowerCamelCase.
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments, user_arguments)
      return result
    end

    # Retrieve variables
    include_demand_nodes = runner.getBoolArgumentValue('include_demand_nodes', user_arguments)
    if include_demand_nodes
      runner.registerInfo("Demand nodes will be included. This can lead to many nodes and large file sizes that may strain your comupter's capabilities.")
    end

    reporting_frequency = runner.getStringArgumentValue("reporting_frequency", user_arguments)

    # Reporting variables
    var_hash = {
      'System Node Temperature' => true,
      'System Node Setpoint Temperature' => false,
      'System Node Mass Flow Rate' => true,
      'System Node Humidity Ratio' => false,
      'System Node Setpoint High Temperature' => false,
      'System Node Setpoint Low Temperature' => false,
      'System Node Setpoint Humidity Ratio' => false,
      'System Node Setpoint Minimum Humidity Ratio' => false,
      'System Node Setpoint Maximum Humidity Ratio' => false,
      'System Node Relative Humidity' => false,
      'System Node Pressure' => false,
      'System Node Standard Density Volume Flow Rate' => false,
      'System Node Current Density Volume Flow Rate' => false,
      'System Node Current Density' => false,
      'System Node Enthalpy' => false,
      'System Node Wetbulb Temperature' => false,
      'System Node Dewpoint Temperature' => false,
      'System Node Quality' => false,
      'System Node Height' => false
    }
    variable_names = []
    var_hash.each do |k, v|
      temp_var = runner.getBoolArgumentValue(k, user_arguments)
      if temp_var
        variable_names << k
      end
    end

    # Get model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model in energyPlusOutputRequests, cannot request outputs for HVAC equipment.')
      return result
    end
    model = model.get

    # Report initial condition of model
    init_number_variables = model.getOutputVariables.size
    runner.registerInitialCondition("The model started out with #{init_number_variables} output variables")

    # Add output variables for nodes
    node_names = []
    loops = []
    model.getAirLoopHVACs.each { |l| loops << l}
    model.getPlantLoops.each { |l| loops << l}
    loops.each do |loop|
      # add the supply objects
      supply_objects = loop.supplyComponents(OpenStudio::Model::Node::iddObjectType)
      node_names = add_node_names_to_array(supply_objects, node_names)

      # also add the outside air system nodes if an air loop
      if loop.to_AirLoopHVAC.is_initialized
        loop = loop.to_AirLoopHVAC.get
        oa_objects = loop.oaComponents(OpenStudio::Model::Node::iddObjectType)
        node_names = add_node_names_to_array(oa_objects, node_names)
      end

      # optionally include demand nodes
      if include_demand_nodes
        demand_objects = loop.demandComponents(OpenStudio::Model::Node::iddObjectType)
        node_names = add_node_names_to_array(demand_objects, node_names)
      end
    end

    # Make it unique, just in case (shouldn't be a problem at all)
    node_names.uniq!

    num_var_to_create = variable_names.size * node_names.size
    runner.registerInfo("<b style='color: #00529B;background-color:#BDE5F8;'>We found #{node_names.size} corresponding Nodes.</b>\n")
    runner.registerInfo("<b>==> #{node_names.size} nodes x #{variable_names.size} variables = <span style='color:#862d2d'>#{num_var_to_create} variables to create.</span></b>\n")

    # Add the output variables
    result = OpenStudio::IdfObjectVector.new
    node_names.each { |node_name|
      variable_names.each { |variable_name|
        result << OpenStudio::IdfObject.load("Output:Variable,#{node_name},#{variable_name},#{reporting_frequency};").get
      }
    }

    return result
  end

  def annual_run_period(sql)
    # get the weather file run period (as opposed to design day run period)
    ann_env_pd = nil
    sql.availableEnvPeriods.each do |env_pd|
      env_type = sql.environmentType(env_pd)
      if env_type.is_initialized
        if env_type.get == OpenStudio::EnvironmentType.new('WeatherRunPeriod')
          ann_env_pd = env_pd
        end
      end
    end

    return ann_env_pd
  end

  def straight_component_data_hash(comp, reporting_frequency, variable_names)
    comp_data = {}
    comp = comp.to_StraightComponent.get
    comp_data['object_name'] = comp.name.to_s
    comp_data['object_type'] = comp.iddObjectType.valueName.to_s
    comp_data['before_objects'] = []
    comp_data['after_objects'] = []
    if comp.inletModelObject.is_initialized
      if comp.inletModelObject.get.name.is_initialized
        inlet_object_name = comp.inletModelObject.get.name.get
        if comp.loop.get.name.get.to_s == inlet_object_name
          # don't log the air loop for the supply inlet node
        else
          # use the component name as is
          comp_data['before_objects'] = [inlet_object_name]
        end
      elsif comp.inletModelObject.get.iddObjectType.valueName.to_s == 'OS_PortList'
        inlet_object_name = comp.inletModelObject.get.to_PortList.get.thermalZone.name.to_s
        comp_data['before_objects'] = [inlet_object_name]
      end
    end
    if comp.outletModelObject.is_initialized
      if comp.outletModelObject.get.name.is_initialized
        outlet_object_name = comp.outletModelObject.get.name.get
        if comp.loop.get.name.get.to_s == outlet_object_name
          # don't log the air loop for the supply outlet node
        else
          comp_data['after_objects'] = [outlet_object_name]
        end
      elsif comp.outletModelObject.get.iddObjectType.valueName.to_s == 'OS_PortList'
        outlet_object_name = comp.outletModelObject.get.to_PortList.get.thermalZone.name.to_s
        comp_data['after_objects'] = [outlet_object_name]
      end
    end

    if comp.to_Node.is_initialized && !variable_names.empty?
      sql = comp.model.sqlFile.get
      ann_env_pd = annual_run_period(sql)

      variable_names.each do |variable_name|
        snake_case_name = variable_name.downcase.gsub(' ', '_')
        rounding_digits = snake_case_name.include?('temperature') ? 1 : 3
        timeseries = sql.timeSeries(ann_env_pd, reporting_frequency, variable_name, comp.name.to_s)
        unless timeseries.empty?
          comp_data["#{snake_case_name}"] = timeseries.get.values.map { |t| t.round(rounding_digits) }
        else
          comp_data["#{snake_case_name}"] = []
        end
      end
    end

    return comp_data
  end

  def hvac_component_data_hash(comp, reporting_frequency, variable_names, loop_data)
    comp_data = {}
    comp = comp.to_HVACComponent.get
    comp_data['object_name'] = comp.name.to_s
    comp_data['object_type'] = comp.iddObjectType.valueName.to_s
    comp_data['before_objects'] = []
    comp_data['after_objects'] = []

    # capture outdoor air system properties
    if comp.to_AirLoopHVACOutdoorAirSystem.is_initialized
      comp = comp.to_AirLoopHVACOutdoorAirSystem.get
      if comp.outboardOANode.is_initialized
        oa_node = comp.outboardOANode.get
        comp_data['before_objects'] << oa_node.name.get
        temp_comp = straight_component_data_hash(oa_node, reporting_frequency, variable_names)
        temp_comp['component_side'] = 'outdoor'
        loop_data['components'] << temp_comp
      end
      if comp.returnAirModelObject.is_initialized
        comp_data['before_objects'] << comp.returnAirModelObject.get.name.get
      end
      if comp.outboardReliefNode.is_initialized
        relief_node = comp.outboardReliefNode.get
        comp_data['after_objects'] << relief_node.name.get
        temp_comp = straight_component_data_hash(relief_node, reporting_frequency, variable_names)
        temp_comp['component_side'] = 'relief'
        loop_data['components'] << temp_comp
      end
      if comp.mixedAirModelObject.is_initialized
        comp_data['after_objects'] << comp.mixedAirModelObject.get.name.get
      end
    elsif comp.to_Splitter.is_initialized
      # if the object is a splitter, log the inlet node and all outlet nodes
      comp = comp.to_Splitter.get
      comp_data['before_objects'] = [comp.inletModelObject.get.name.get] if comp.inletModelObject.is_initialized
      comp.outletModelObjects.each { |obj| comp_data['after_objects'] << obj.name.get }
    elsif comp.to_Mixer.is_initialized
      # if the object is a mixer, log all inlet nodes and the outlet node
      comp = comp.to_Mixer.get
      comp.inletModelObjects.each { |obj| comp_data['before_objects'] << obj.name.get }
      comp_data['after_objects'] = [comp.outletModelObject.get.name.get] if comp.outletModelObject.is_initialized
    elsif comp.to_ThermalZone.is_initialized
      comp = comp.to_ThermalZone.get
      comp.inletPortList.modelObjects.each { |obj| comp_data['before_objects'] << obj.name.get }
      comp.returnPortList.modelObjects.each { |obj| comp_data['after_objects'] << obj.name.get }
    elsif comp.to_WaterToAirComponent.is_initialized
      comp = comp.to_WaterToAirComponent.get
      comp_data['before_objects'] << comp.airInletModelObject.get.name.get if comp.airInletModelObject.is_initialized
      comp_data['before_objects'] << comp.waterInletModelObject.get.name.get if comp.waterInletModelObject.is_initialized
      comp_data['after_objects'] << comp.airOutletModelObject.get.name.get if comp.airOutletModelObject.is_initialized
      comp_data['after_objects'] << comp.waterOutletModelObject.get.name.get if comp.waterOutletModelObject.is_initialized
    elsif comp.to_WaterToWaterComponent.is_initialized
      comp = comp.to_WaterToWaterComponent.get
      comp_data['before_objects'] << comp.demandInletModelObject.get.name.get if comp.demandInletModelObject.is_initialized
      comp_data['before_objects'] << comp.supplyInletModelObject.get.name.get if comp.supplyInletModelObject.is_initialized
      comp_data['before_objects'] << comp.tertiaryInletModelObject.get.name.get if comp.tertiaryInletModelObject.is_initialized
      comp_data['after_objects'] << comp.demandOutletModelObject.get.name.get if comp.demandOutletModelObject.is_initialized
      comp_data['after_objects'] << comp.supplyOutletModelObject.get.name.get if comp.supplyOutletModelObject.is_initialized
      comp_data['after_objects'] << comp.tertiaryOutletModelObject.get.name.get if comp.tertiaryOutletModelObject.is_initialized
    end

    return comp_data
  end

  def add_node_names_to_array(model_objects, node_names)
    model_objects.each do |model_object|
      unless model_object.to_Node.empty?
        model_node = model_object.to_Node.get
        # A node necessarily has a name
        node_names << model_node.name.get
      end
    end

    return node_names
  end

  def loop_boundary_nodes(loop)
    node_list = {}
    node_list['supply_inlet'] = loop.supplyInletNode.name.get
    node_list['supply_outlet'] = loop.supplyOutletNode.name.get
    node_list['demand_inlet'] = loop.demandInletNode.name.get
    node_list['demand_outlet'] = loop.demandOutletNode.name.get

    return node_list
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments, user_arguments)
      return false
    end

    # Retrieve variables
    include_demand_nodes = runner.getBoolArgumentValue('include_demand_nodes', user_arguments)
    reporting_frequency = runner.getStringArgumentValue('reporting_frequency', user_arguments)

    # Reporting variables
    var_hash = {
      'System Node Temperature' => true,
      'System Node Setpoint Temperature' => false,
      'System Node Mass Flow Rate' => true,
      'System Node Humidity Ratio' => false,
      'System Node Setpoint High Temperature' => false,
      'System Node Setpoint Low Temperature' => false,
      'System Node Setpoint Humidity Ratio' => false,
      'System Node Setpoint Minimum Humidity Ratio' => false,
      'System Node Setpoint Maximum Humidity Ratio' => false,
      'System Node Relative Humidity' => false,
      'System Node Pressure' => false,
      'System Node Standard Density Volume Flow Rate' => false,
      'System Node Current Density Volume Flow Rate' => false,
      'System Node Current Density' => false,
      'System Node Enthalpy' => false,
      'System Node Wetbulb Temperature' => false,
      'System Node Dewpoint Temperature' => false,
      'System Node Quality' => false,
      'System Node Height' => false
    }
    variable_names = []
    var_hash.each do |k, v|
      temp_var = runner.getBoolArgumentValue(k, user_arguments)
      if temp_var
        variable_names << k
      end
    end

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError('Cannot find last model.')
      return false
    end
    model = model.get

    sql = runner.lastEnergyPlusSqlFile
    if sql.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sql = sql.get
    model.setSqlFile(sql)

    # get the weather file run period (as opposed to design day run period)
    ann_env_pd = annual_run_period(sql)
    if ann_env_pd.nil?
      runner.registerError('Cannot find a weather runperiod. Make sure you ran an annual simulation, not just the design days.')
      return false
    end

    # log data from AirLoopHVACs and PlantLoops
    hvac_data = []
    model.getLoops.each do |hvac_loop|
      loop_data = {}
      loop_data['loop_name'] = hvac_loop.name.to_s
      loop_data['loop_type'] = hvac_loop.iddObjectType.valueName.to_s
      loop_data['boundary_nodes'] = loop_boundary_nodes(hvac_loop)
      loop_data['components'] = []
      # loop through supply side components and add them to components array
      hvac_loop.supplyComponents.each do |comp|
        if comp.to_StraightComponent.is_initialized
          comp_data = straight_component_data_hash(comp, reporting_frequency, variable_names)
        else
          comp_data = hvac_component_data_hash(comp, reporting_frequency, variable_names, loop_data)
        end
        comp_data['component_side'] = 'supply'
        loop_data['components'] << comp_data
      end
      # loop through demand side components and add them to components array
      hvac_loop.demandComponents.each do |comp|
        if comp.to_StraightComponent.is_initialized
          variable_names = [] unless include_demand_nodes
          comp_data = straight_component_data_hash(comp, reporting_frequency, variable_names)
        else
          comp_data = hvac_component_data_hash(comp, reporting_frequency, variable_names, loop_data)
        end
        comp_data['component_side'] = 'demand'
        loop_data['components'] << comp_data
      end

      # connect supply outlet and demand inlet
      supply_outlet = loop_data['components'].select { |comp|  comp['object_name'] == loop_data['boundary_nodes']['supply_outlet'] }[0]
      demand_inlet = loop_data['components'].select { |comp|  comp['object_name'] == loop_data['boundary_nodes']['demand_inlet'] }[0]
      supply_outlet['after_objects'] << loop_data['boundary_nodes']['demand_inlet']
      demand_inlet['before_objects'] << loop_data['boundary_nodes']['supply_outlet']

      # connect demand outlet and supply inlet
      demand_outlet = loop_data['components'].select { |comp|  comp['object_name'] == loop_data['boundary_nodes']['demand_outlet'] }[0]
      supply_inlet = loop_data['components'].select { |comp|  comp['object_name'] == loop_data['boundary_nodes']['supply_inlet'] }[0]
      demand_outlet['after_objects'] << loop_data['boundary_nodes']['supply_inlet']
      supply_inlet['before_objects'] << loop_data['boundary_nodes']['demand_outlet']

      hvac_data << loop_data
    end

    # Convert the hash to a JSON string
    hvac_data = JSON.pretty_generate(hvac_data)

    # Write the JSON string to the file
    File.open('hvac_data.json', 'w') do |file|
      file.write(hvac_data)
    end

		# Begin HTML writing process
		web_asset_path = OpenStudio.getSharedResourcesPath() / OpenStudio::Path.new("web_assets")

    # read in template
    html_in_path = "#{File.dirname(__FILE__)}/resources/report.html.erb"
    if File.exist?(html_in_path)
      html_in_path = html_in_path
    else
      html_in_path = "#{File.dirname(__FILE__)}/report.html.erb"
    end
    html_in = ''
    File.open(html_in_path, 'r') do |file|
      html_in = file.read
    end

    # configure template with variable values
    renderer = ERB.new(html_in)
    html_out = renderer.result(binding)

    # write html file
    html_out_path = './detailed_hvac_report.html'
    File.open(html_out_path, 'w') do |file|
      file << html_out
      # make sure data is written to the disk one way or the other
      begin
        file.fsync
      rescue StandardError
        file.flush
      end
    end

    # close the sql file
    sql.close

    # Report final condition of model
    return true
  end
end

# register the measure to be used by the application
DetailedHVACViewer.new.registerWithApplication
