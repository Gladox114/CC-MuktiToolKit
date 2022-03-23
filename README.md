# CC-MuktiToolKit

A program that uses its own local coordinates to orient itself and walk easily to vector positions.

### The base
Needs two chest positions saved as a vector with a direction value to know in what direction to access the chests.
Two chests are needed. One with empty space to drop the items in (it will assert if there is no chest so no worries about despawning items) and the other one to put coal in so it can refuel there.
The turtle begins with (0/0/0) as start position and faces North/+x in its virtual space. You can change everything if you understand the code.

This program checks if it needs to refuel and refuels itself automaticly if the check routine is triggered.
Goes to deposit chest to first empty itself to then refuel itself at the refuel chest if its empty on coal or charcoal.
It empties itself automaticly when full. 

### The tools

#### Strip Mining:
When torches found in the inventory then it will place torches at a custom distance between the torches.
Everything important about the strip mining is customizable with variables in the top location of the code.

#### Excavate
The turtle will excavate a cuboid at its front face.
From the startposition + 1 forward facing forward it will excavate your custom set variables left,right,forward,up and down.
The rest is taken in the turtles hand.
