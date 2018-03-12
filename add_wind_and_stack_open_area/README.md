#Description
This measure models natural ventilation to thermal zones with operable windows.  It is not intended to model natural ventilation that relies on interzone, stack driven air transfer.

#Modeler Description
This measure adds ZoneVentilation:WindandStackOpenArea objects to a zone for each window of a specified operable window construction.  The user can specify values for minimum and maximum zone and outdoor air temperatures and wind speed that set limits on when the ventilation is active. The airflow rate is the quadrature sum of wind driven and stack effect driven air flow.  Airflow driven by wind is a function of opening effectiveness, area, scheduled open area fraction, and wind speed.  Airflow driven by the stack effect is a function of the discharge coefficient, area, scheduled open area fraction, and height difference to the neutral pressure level.  This measure takes the height difference as half the window height, and as such is only intended to model natural ventilation in single zones where a few large operable windows or doors account for the majority of operable area.  It is not intended to model natural ventilation that relies on interzone, stack driven air transfer where ventilation flow through a opening is unidirectional.

#Background
A key variable in the natural ventilation calculation is the height difference between the midpoint of the lower opening and the neutral pressure level. Estimation of the height difference is difficult for naturally ventilated buildings. Chapter 16 of the 2017 ASHRAE Handbook of Fundamentals suggests that "if one window or door represents a large fraction (approximately 90%) of the total opening area in the envelope, then the NPL is at the mid-height of that aperture, and delta_H_NPL equals one-half the height of the aperture".  This measure uses this assumption, and automatically calculates the height difference at one half the window height.  This assumes the flow through the opening is bidirectional (i.e., air from the warmer side flows through the top of the opening, and air from the colder side flows through the bottom), and is intended to model natural ventilation in isolated zones.  It is not intended to model stack-driven ventilation across multiple thermal zones in a multi-story building where flow through an opening is unidirectional.  The Airflow Network Model is more appropriate for inter-zone, stack-driven flows.  See the EnergyPlus Input Output Reference ZoneVentilation:WindandStackOpenArea section and EnergyPlus Engineering Reference Ventilation by Wind and Stack with Open Area section for more detail.

#Relevant Unmet Hours Threads:
https://unmethours.com/question/21804/why-is-average-window-height-in-m2/
https://unmethours.com/question/25647/no-change-in-zone-temperature-beforeafter-wind-and-stack-open-area-measure/

#Github Repository
https://github.com/UnmetHours/openstudio-measures/tree/master/add_wind_and_stack_open_area

#Measure Updates March 12th, 2018 by Matthew Dahlhausen
- Changed inputs to have user selected a open area fraction schedule
- Changed inputs to have user select an operable window construction
- Measure now adds ZoneVentilation:WindandStackOpenArea objects per window instead of per zone
- Measure now calculates operable area based on window geometry
- Measure now calculates effective angle based on the surface normal of a given window
- Measure now calculates height difference to neutral pressure level as half window height