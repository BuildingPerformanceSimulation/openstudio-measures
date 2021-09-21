This measure is an EnergyPlus measure that edits IdealLoadsAirSystem objects in the .idf file at runtime.

HVACTemplate objects, including HVACTemplate:Zone:IdealLoadsAirSystem objects, are translated into EnergyPlus objects (ZoneHVAC:IdealLoadsAirSystem objects) in the Expand Objects step.

In OpenStudio version 1, the order of operations is:
Expand Objects -> EnergyPlus Measures -> Pre-Process

In OpenStudio version 2, the order of operations is:
EnergyPlus Measures -> Expand Objects -> Pre-Process

This means to edit fields, the measure edits ZoneHVAC:IdealLoadsAirSystem objects in OS version <=1.14 and HVACTemplate:Zone:IdealLoadsAirSystem stage in OS version >= 2.0.

The default measure.rb script in this folder is set up to edit HVACTemplate:Zone:IdealLoadsAirSystem objects, and works with only OpenStudio versions 2.+.  There is a version toggle at the start of the run method to manually change this measure to run in OpenStudio version 1.14 and earlier.

See this GitHub issue for more detail: https://github.com/NREL/OpenStudio/issues/2799