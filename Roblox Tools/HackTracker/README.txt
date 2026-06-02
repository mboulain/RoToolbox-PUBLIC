HackTracker is a roblox tool made to "simulate" hacking capabilities. It doesn't have the purpose to be used to hack other games!

How to use ?
It is actually very easy to use.

1- Require the module based on where you stored it.
2- Declare a new HackTracker by stating
---> local hackTracker = HackTracker.new()

HackTracker can have up to 3 arguments (all are optional)

A -> toggleKey :: Enum.KeyCode? Used to toggle the HackTracker window in your game. Default is F6
B -> defaultVisibility :: boolean? Used to decide if the window is on or off when declared. Default is false.
C -> printForDebug :: boolean? Used to print all the remote events found by HackTracker to use. Default is false.


Note 1 : HackTracker is planned to be used CLIENT-SIDE only. It doesn't work on the server for obvious reasons.
Note 2 : HackTracker is automatically removed from the game if you're not in Roblox Studio for obvious reasons.