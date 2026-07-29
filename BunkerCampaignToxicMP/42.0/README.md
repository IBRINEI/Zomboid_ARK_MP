# Bunker Campaign: Toxic Zones MP Fork

The original resources, clothing, models, sounds and recipes are retained. The
original client-owned damage handler and client-written admin panel are not
loaded.

The server owns zone membership, exposure, filter charge and death. Filter
charge is retained by item id, so stale worn-item packets cannot refill it.
Clients receive display-only exposure snapshots for the overlay and Geiger sounds.
The server also owns persistent surface contamination for the current body,
worn equipment and a bounded set of carried items. Item contamination is stored
in item modData and remains separate from inhaled exposure and mask-filter charge.
Filter insertion/removal recipes preserve `modData.percent` through the B42
`craftRecipe` OnCreate API and do not require a crafting surface. The server
uses the B42 item-modData synchronization packet after every filter drain, and
the client tooltip shows the remaining charge as an exact percentage. A dead
character's exposure record is cleared before the replacement character's
first status response.

Do not enable `ToxicZonesSTALKERB42` together with this fork.
