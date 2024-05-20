# Detailed HVAC Viewer Data Schema

## Description
The viewer takes a .json file to render the HVAC loops. The highest level is an array of hashes, with each hash listening an `object_name` and OpenStudio `object_type` of either an AirLoopHVAC or PlantLoop object. Each loop hash has a field components, which is an array of hashes of all the components on that air loop. The component has lists the `object_name`, OpenStudio `object_type`, and `component_type` to specify whether the component is on the supply side or return side of the loop. Each component hash also includes an array of `before_objects` and `after_objects` which is used to determine the order items appear in the loop. Node objects include an array of doubles for all the desired output variables to plot.

Example schema:
```
[
  {
    "object_name": "5 Zone PVAV",
    "object_type": "OS_AirLoopHVAC",
    "components": [
      {
        "object_name": "5 Zone PVAV Supply Inlet Node",
        "object_type": "OS_Node",
        "before_objects": [
          "5 Zone PVAV"
        ],
        "after_objects": ["5 Zone PVAV OA System"],
        "system_node_temperature": [17.1,17.1],
        "system_node_mass_flow_rate": [0.0,0.0],
        "component_type": "supply"
      },
      {
        "object_name": "5 Zone PVAV Outdoor Air Node",
        "object_type": "OS_Node",
        "after_objects": [
          "5 Zone PVAV OA System"
        ],
        "system_node_temperature": [-3.5, -5.2],
        "system_node_mass_flow_rate": [0.0, 0.0]
      },
      {
        "object_name": "5 Zone PVAV OA System",
        "object_type": "OS_AirLoopHVAC_OutdoorAirSystem",
        "before_objects": [
          "5 Zone PVAV Outdoor Air Node",
          "5 Zone PVAV Supply Inlet Node"
        ],
        "after_objects": [
          "5 Zone PVAV Relief Air Node",
          "5 Zone PVAV Mixed Air Node"
        ],
        "component_type": "supply"
      }
    ]
  }
]
```