Map          : acropolis3.map
Format       : Brush Primitives
Creator      : SkinHat
Description  : There isn't any entities (even lights)

Map          : acropolis4.map
Format       : Brush Primitives
Creator      : SkinHat
Modification : Osman Turan
Description  : Completely based on acropolis3. Just added some entities 
               (light, player start etc.) and closed the world for avoiding map leaks.

Map          : softshadows.map
Format       : Brush Primitives
Creator      : Osman Turan
Description  : Testing for light jittering and low sampling (means better) lightmapping.
               There are only 3 three lights (red, green, blue). But, the compiler is
               producing 24 lights for light jittering effect.

Map          : hardshadows.map
Format       : Brush Primitives
Creator      : Osman Turan
Description  : Testing for low sampling (means better) lightmapping with very bright light.
               Most compilers produce very bad shadow artifacts at this compiling options.

Map          : bigbox.map
Format       : Brush Primitives
Creator      : Osman Turan
Description  : Testing for normalmapped (bumpmapped) lightmapping at low sampling (means better).
               There are two lights.

Map          : dungeon.map
Format       : Brush Primitives
Creator      : Osman Turan
Description  : Testing for linear lighting which simulates per-pixel lighting style attenuation.

Map          : doom3_test.map
Format       : Doom3 Primitives
Creator      : id Software
Original Name: test_box.map
Description  : Just for testing Doom III .map formats

Map          : classicquake.map
Format       : Classic Quake
Creator      : Osman Turan
Description  : Just for testing Classic Quake .map formats