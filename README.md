# CC-MuktiToolKit

A program that uses its own local coordinates to orient itself and walk easily to vector positions.

### The base
Needs two chest positions saved as a vector with a direction value to know in what direction to access the chests.
This program checks if it needs to refuel and refuels itself automaticly if the check routine is triggered.
Goes to refuel chest if its empty on coal or charcoal.
It empties itself automaticly when full. 

Currently there is only one function which only strip mines.
When torches found in the inventory then it will place torches at a custom distance between the torches.
Everything important about the strip mining is customizable with variables in the top location of the code.
