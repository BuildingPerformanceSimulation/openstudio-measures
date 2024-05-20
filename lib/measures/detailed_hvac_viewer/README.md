

###### (Automatically generated documentation)

# Detailed HVAC Viewer

## Description
This measure creates a facsimile of the HVAC grid layout in the OpenStudio Application in an interactive html report. The user can optionally select loops to add Output:Variable to view node timeseries output data.

## Modeler Description
The user is asked to provided the following parameters:
- A plantLoop or airLoop from the model (dropdown)
- A boolean to include or exclude demand nodes
- Which variable they want to output for each node:
    * System Node Temperature
    * System Node Setpoint Temperature
    * System Node Mass Flow Rate
    * etc.

Developed as part of HackSimBuild 2024 by Matthew Dahlhausen and Ken Takahashi

## Measure Type
ReportingMeasure

## Taxonomy


## Arguments


### Include Demand Side nodes in the timeseries output?

**Name:** include_demand_nodes,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### <h3>Select a Reporting Frequency?</h3>

**Name:** reporting_frequency,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Temperature

**Name:** System Node Temperature,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Setpoint Temperature

**Name:** System Node Setpoint Temperature,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Mass Flow Rate

**Name:** System Node Mass Flow Rate,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Humidity Ratio

**Name:** System Node Humidity Ratio,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Setpoint High Temperature

**Name:** System Node Setpoint High Temperature,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Setpoint Low Temperature

**Name:** System Node Setpoint Low Temperature,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Setpoint Humidity Ratio

**Name:** System Node Setpoint Humidity Ratio,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Setpoint Minimum Humidity Ratio

**Name:** System Node Setpoint Minimum Humidity Ratio,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Setpoint Maximum Humidity Ratio

**Name:** System Node Setpoint Maximum Humidity Ratio,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Relative Humidity

**Name:** System Node Relative Humidity,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Pressure

**Name:** System Node Pressure,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Standard Density Volume Flow Rate

**Name:** System Node Standard Density Volume Flow Rate,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Current Density Volume Flow Rate

**Name:** System Node Current Density Volume Flow Rate,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Current Density

**Name:** System Node Current Density,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Enthalpy

**Name:** System Node Enthalpy,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Wetbulb Temperature

**Name:** System Node Wetbulb Temperature,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Dewpoint Temperature

**Name:** System Node Dewpoint Temperature,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Quality

**Name:** System Node Quality,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### System Node Height

**Name:** System Node Height,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false




