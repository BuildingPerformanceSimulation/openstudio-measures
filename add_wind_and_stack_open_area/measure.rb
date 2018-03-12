#start the measure
class AddWindAndStackOpenArea < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see
  def name
    return "Add Wind and Stack Open Area"
  end

  ###
  #code to determine the area of a polygon from an array of vertices
  #https://stackoverflow.com/questions/12642256/python-find-area-of-polygon-from-xyz-coordinates
  
  #determinant of matrix a
  def det(a)
    return a[0][0]*a[1][1]*a[2][2] + a[0][1]*a[1][2]*a[2][0] + a[0][2]*a[1][0]*a[2][1] - a[0][2]*a[1][1]*a[2][0] - a[0][1]*a[1][0]*a[2][2] - a[0][0]*a[1][2]*a[2][1]
  end

  #unit normal vector of plane defined by points a, b, and c
  def unitNormal(a, b, c)
    x = det([[1,a[1],a[2]],
             [1,b[1],b[2]],
             [1,c[1],c[2]]])
    y = det([[a[0],1,a[2]],
             [b[0],1,b[2]],
             [c[0],1,c[2]]])
    z = det([[a[0],a[1],1],
             [b[0],b[1],1],
             [c[0],c[1],1]])
    magnitude = (x**2 + y**2 + z**2)**0.5
    return [x/magnitude, y/magnitude, z/magnitude]
  end

  #dot product of vectors a and b
  def dot(a, b)
    return a[0]*b[0] + a[1]*b[1] + a[2]*b[2]
  end

  #cross product of vectors a and b
  def cross(a, b)
    x = a[1] * b[2] - a[2] * b[1]
    y = a[2] * b[0] - a[0] * b[2]
    z = a[0] * b[1] - a[1] * b[0]
    return [x, y, z]
  end

  #area of polygon poly
  def area(poly)
    if poly.length < 3 # not a plane - no area
      return 0
    end

    total = [0, 0, 0]
    for i in (0..(poly.length-1))
      vi1 = poly[i]
      if i == (poly.length-1)
        vi2 = poly[0]
      else
        vi2 = poly[i+1]
      end
      prod = cross(vi1, vi2)
      total[0] += prod[0]
      total[1] += prod[1]
      total[2] += prod[2]
    end
    
    result = dot(total, unitNormal(poly[0], poly[1], poly[2]))
    return (result/2).abs
  end
  ###
  
  def getWindowBoundaryCondition(workspace,window)
    surface_name = window.getString(3).to_s
    surface = workspace.getObjectsByTypeAndName("BuildingSurface:Detailed".to_IddObjectType,surface_name)[0]
    boundary_condition = surface.getString(4).to_s
    return boundary_condition
  end
  
  def getWindowZoneName(workspace,window)
    surface_name = window.getString(3).to_s
    surface = workspace.getObjectsByTypeAndName("BuildingSurface:Detailed".to_IddObjectType,surface_name)[0]
    zone_name = surface.getString(3).to_s
    return zone_name
  end
  
  def getWindowArea(workspace,window)
    #function to calculate window area
    #assumes 4 vertices, but could handle more if fenestration surfaces in EnergyPlus gets extended to handle more in the future
    
    #get x,y,z values of vertices from window object
    x1 = window.getDouble(10).get
    y1 = window.getDouble(11).get
    z1 = window.getDouble(12).get
    y2 = window.getDouble(14).get
    x2 = window.getDouble(13).get
    z2 = window.getDouble(15).get
    x3 = window.getDouble(16).get
    y3 = window.getDouble(17).get
    z3 = window.getDouble(18).get
    x4 = window.getDouble(19).get
    y4 = window.getDouble(20).get
    z4 = window.getDouble(21).get
    
    vertices = []
    vertices << [x1,y1,z1]
    vertices << [x2,y2,z2]
    vertices << [x3,y3,z3]
    vertices << [x4,y4,z4]
    
    return area(vertices)
  end

  def getWindowHeightDifference(workspace,window)
    #function  to calculate height of window
    
    #assume z coordinates
    z_values = []
    z_values << window.getDouble(12).get
    z_values << window.getDouble(15).get
    z_values << window.getDouble(18).get
    z_values << window.getDouble(21).get
    
    zmin = z_values[0]
    zmax = z_values[0]
    z_values.each do |z|
      if z < zmin
        zmin = z
      end
      if z > zmax
        zmax =z
      end
    end
    
    height = (zmax - zmin)
    return height/2.0
  end
  
  def getWindowEffectiveAngle(workspace,window)
    surface_name = window.getString(3).to_s
    surface = workspace.getObjectsByTypeAndName("BuildingSurface:Detailed".to_IddObjectType,surface_name)[0]
    #get x,y,z values of first three vertices from surface object
    x1 = surface.getDouble(10).get
    y1 = surface.getDouble(11).get
    z1 = surface.getDouble(12).get
    y2 = surface.getDouble(14).get
    x2 = surface.getDouble(13).get
    z2 = surface.getDouble(15).get
    x3 = surface.getDouble(16).get
    y3 = surface.getDouble(17).get
    z3 = surface.getDouble(18).get
    surface_unit_normal = unitNormal([x1,y1,z1],[x2,y2,z2],[x3,y3,z3])
    
    surface_angle = Math.atan2(surface_unit_normal[0],surface_unit_normal[1]) * 180 / Math::PI
    
    #get zone direction of relative north
    zone_name = surface.getString(3).to_s
    zone = workspace.getObjectsByTypeAndName("Zone".to_IddObjectType,zone_name)[0]
    relative_north = 0
    if !zone.getDouble(1).empty?
      relative_north = zone.getDouble(1).get
    end
    
    angle = surface_angle + relative_north
    if angle < 0
      angle += 360
    end
    if angle > 360
      angle +- 360
    end
    return angle
  end
  
  #define the arguments that the user will input
  def arguments(workspace)
    args = []
    
    #make an argument to pick a construction to apply it too
    #This is used because the workspace objects lack the FixedWindow and OperableWindow Sub Surface Type object variable available for subsurfaces in the OpenStudio model
    construction_choices = OpenStudio::StringVector.new
    constructions = workspace.getObjectsByType("Construction".to_IddObjectType)
    construction_choices << ""
    constructions.each do |construction|
      construction_choices << construction.getString(0).to_s
    end
    #argument for construction
    construction = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("construction", construction_choices, true)
    construction.setDisplayName("Window Construction for Operable Windows:")
    construction.setDescription("(Leave blank to apply to all windows)")
    construction.setDefaultValue("")
    args << construction
    
    #make choice argument for fractional schedule
    sch_choices = OpenStudio::StringVector.new
    sch_compacts = workspace.getObjectsByType("Schedule:Compact".to_IddObjectType)
    sch_constants = workspace.getObjectsByType("Schedule:Constant".to_IddObjectType)
    sch_years = workspace.getObjectsByType("Schedule:Year".to_IddObjectType)
    sch_files = workspace.getObjectsByType("Schedule:File".to_IddObjectType)
    sch_compacts.each do |sch|
      if sch.getString(1).to_s.downcase == "fractional"
        sch_choices << sch.getString(0).to_s
      end
    end
    sch_constants.each do |sch|
      if sch.getString(1).to_s.downcase == "fractional"
        sch_choices << sch.getString(0).to_s
      end
    end    
    sch_years.each do |sch|
      if sch.getString(1).to_s.downcase == "fractional"
        sch_choices << sch.getString(0).to_s
      end
    end
    sch_files.each do |sch|
      if sch.getString(1).to_s.downcase == "fractional"
        sch_choices << sch.getString(0).to_s
      end
    end
    
	  #make an argument for open area fraction
    open_area_fraction_schedule = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("open_area_fraction_schedule",sch_choices,true)
    open_area_fraction_schedule.setDisplayName("Open Area Fraction Schedule")
    open_area_fraction_schedule.setDescription("A typical operable window does not open fully.  The actual opening area in a zone is the product of the area of operable windows and the open area fraction schedule.")
    args << open_area_fraction_schedule

	  #make an argument for min indoor temp
    min_indoor_temp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("min_indoor_temp",true)
    min_indoor_temp.setDisplayName("Minimum Indoor Temperature (degC)")
    min_indoor_temp.setDescription("The indoor temperature below which ventilation is shutoff.")
    min_indoor_temp.setDefaultValue(10.0)
    args << min_indoor_temp

	  #make an argument for max indoor temp
    max_indoor_temp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("max_indoor_temp",true)
    max_indoor_temp.setDisplayName("Maximum Indoor Temperature (degC)")
    max_indoor_temp.setDescription("The indoor temperature above which ventilation is shutoff.")
    max_indoor_temp.setDefaultValue(60.0)
    args << max_indoor_temp

	  #make an argument for delta temp
    delta_temp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("delta_temp",true)
    delta_temp.setDisplayName("Maximum Indoor-Outdoor Temperature Difference (degC)")
    delta_temp.setDescription("This is the temperature difference between the indoor and outdoor air dry-bulb
temperatures below which ventilation is shutoff.  For example, a delta temperature of 2 degC means ventilation is available if the outside air temperature is at least 2 degC cooler than the zone air temperature. Values can be negative.")
    delta_temp.setDefaultValue(0.0)
    args << delta_temp
	
	  #make an argument for min outdoor temp
    min_outdoor_temp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("min_outdoor_temp",true)
    min_outdoor_temp.setDisplayName("Minimum Outdoor Temperature (degC)")
    min_outdoor_temp.setDescription("The outdoor temperature below which ventilation is shut off.")
    min_outdoor_temp.setDefaultValue(18.3333)
    args << min_outdoor_temp
	
	  #make an argument for max outdoor temp
    max_outdoor_temp = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("max_outdoor_temp",true)
    max_outdoor_temp.setDisplayName("Maximum Outdoor Temperature (degC)")
    max_outdoor_temp.setDescription("The outdoor temperature above which ventilation is shut off.")
    max_outdoor_temp.setDefaultValue(25.5556)
    args << max_outdoor_temp
	
	  #make an argument for max wind speed
    max_wind_speed = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("max_wind_speed",true)
    max_wind_speed.setDisplayName("Maximum Wind Speed (m/s)")
    max_wind_speed.setDescription("This is the wind speed above which ventilation is shut off.  The default values assume windows are closed when wind is above a gentle breeze to avoid blowing around papers in the space.")    
    max_wind_speed.setDefaultValue(5.4)
    args << max_wind_speed

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    #assign the user inputs to variables
    construction = runner.getStringArgumentValue("construction",user_arguments)
    open_area_fraction_schedule = runner.getStringArgumentValue("open_area_fraction_schedule",user_arguments)
    min_indoor_temp = runner.getDoubleArgumentValue("min_indoor_temp",user_arguments)
    max_indoor_temp = runner.getDoubleArgumentValue("max_indoor_temp",user_arguments)
    delta_temp = runner.getDoubleArgumentValue("delta_temp",user_arguments)
	  min_outdoor_temp = runner.getDoubleArgumentValue("min_outdoor_temp",user_arguments)
    max_outdoor_temp = runner.getDoubleArgumentValue("max_outdoor_temp",user_arguments)
	  max_wind_speed = runner.getDoubleArgumentValue("max_wind_speed",user_arguments)

    #check value for reasonableness
    if min_indoor_temp < -100.0
      runner.registerError("Please enter a value greater than -100.0 degC for Minimum Indoor Temperature.")
      return false
    elsif min_indoor_temp > 100.0
      runner.registerError("Please enter a value less than 100.0 degC for Minimum Indoor Temperature.")
      return false
    end

    #check value for reasonableness
    if max_indoor_temp < -100.0
      runner.registerError("Please enter a value greater than -100.0 degC for Maximum Indoor Temperature.")
      return false
    elsif max_indoor_temp > 100.0
      runner.registerError("Please enter a value less than 100.0 degC for Maximum Indoor Temperature.")
      return false
    end

    #check value for reasonableness
    if delta_temp < -100.0
      runner.registerError("Please enter a value greater than -100.0 degC for Maximum Indoor-Outdoor Temperature Difference.")
      return false
    elsif delta_temp > 100.0
      runner.registerError("Please enter a value less than 100.0 degC for Maximum Indoor-Outdoor Temperature Difference.")
      return false
    end

    #check value for reasonableness
    if min_outdoor_temp < -100.0
      runner.registerError("Please enter a value greater than -100.0 degC for Minimum Outdoor Temperature.")
      return false
    elsif min_outdoor_temp > 100.0
      runner.registerError("Please enter a value less than 100.0 degC for Minimum Outdoor Temperature.")
      return false
    end

    #check value for reasonableness
    if max_outdoor_temp < -100.0
      runner.registerError("Please enter a value greater than -100.0 degC for Maximum Outdoor Temperature.")
      return false
    elsif max_outdoor_temp > 100.0
      runner.registerError("Please enter a value less than 100.0 degC for Maximum Outdoor Temperature.")
      return false
    end

    #check value for reasonableness
    if max_wind_speed < 0
      runner.registerError("Please enter a non-negative value for maximum wind speed.")
      return false
    end

    idf_objects_to_add = []
    
    #loop through fenestrations finding exterior windows
    fenestrations = workspace.getObjectsByType("FenestrationSurface:Detailed".to_IddObjectType)
    fenestrations.each do |w|
      #(0) is name, (1) is surface type, (2) is construction name, (3) is building surface name, (4) is outside boundary condition object
      next if not w.getString(1).to_s == "Window"
      next if not getWindowBoundaryCondition(workspace,w) == "Outdoors"
      
      #if construction name given, next if window doesn't have that construction
      if not construction == ""
        next if not w.getString(2).to_s == construction
      end
      
      #add ZoneVentilationWindStackOpenArea object for each exterior window
      window_name = w.getString(0).to_s
      zone_name = getWindowZoneName(workspace,w)
      
      #calculate open_area size
      open_area = getWindowArea(workspace,w)
      
      #calculate the height_difference at one half the window height.  See notes for explanation.
      height_difference = getWindowHeightDifference(workspace,w) 
      
      #determine outward normal angle for surface; need one for each window object
      effective_angle = getWindowEffectiveAngle(workspace,w)
      
      #IDF object text for ZoneVentilationWindStackOpenArea
      idf_objects_to_add << "
        ZoneVentilation:WindandStackOpenArea,
        #{window_name}_WindandStackOpenArea, !- Name
        #{zone_name},            !- Zone Name
        #{open_area},            !- Opening Area {m2}
        #{open_area_fraction_schedule},   !- Opening Area Fraction Schedule Name
        Autocalculate,           !- Opening Effectiveness {dimensionless}
        #{effective_angle},      !- Effective Angle {deg}
        #{height_difference},    !- Height Difference {m}
        Autocalculate,           !- Discharge Coefficient for Opening
        #{min_indoor_temp},      !- Minimum Indoor Temperature {C}
        ,                        !- Minimum Indoor Temperature Schedule Name
        #{max_indoor_temp},      !- Maximum Indoor Temperature {C}
        ,                        !- Maximum Indoor Temperature Schedule Name
        #{delta_temp},           !- Delta Temperature {deltaC}
        ,                        !- Delta Temperature Schedule Name
        #{min_outdoor_temp},     !- Minimum Outdoor Temperature {C}
        ,                        !- Minimum Outdoor Temperature Schedule Name
        #{max_outdoor_temp},     !- Maximum Outdoor Temperature {C}
        ,                        !- Maximum Outdoor Temperature Schedule Name
        #{max_wind_speed};       !- Maximum Wind Speed {m/s}
        "
	  end
       
    #add all of the strings to workspace to create IDF objects
    idf_objects_to_add.each do |obj|
      idfObject = OpenStudio::IdfObject::load(obj)
      object = idfObject.get
      wsObject = workspace.addObject(object)
    end
	  
    #check if any objects added for reasonableness
    if idf_objects_to_add.empty?
      runner.registerError("No windows found in selection matching given construction.  This means your model lacks windows or lacks windows with the specified construction.")
      return false
    else
      runner.registerFinalCondition("Added #{idf_objects_to_add.length} ZoneVentilation:WindandStackOpenArea objects")
    end    
    
    return true
  end #end the run method

end #end the measure

#this allows the measure to be used by the application
AddWindAndStackOpenArea.new.registerWithApplication