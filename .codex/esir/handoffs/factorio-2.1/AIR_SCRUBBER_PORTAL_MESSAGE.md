# Draft message for Lord_Curdin's Air Scrubber discussion page

Not posted. Based on inspection of the published `air-scrubber_0.2.9.zip`.

---

Hi Lord_Curdin, thanks for continuing Air Scrubber for 2.1. While integrating
0.2.9 into ESIR, I found a prototype-name mismatch in the quality build handler.

In `control.lua`, the event filter uses the mod ID `air-scrubber`, but the placed
entity still has the prototype name `atan-air-scrubber`. That means the handler
does not run for the actual scrubber, so higher-quality placements keep the base
prototype instead of switching to the quality-specific variant.

The immediate fix is:

```diff
-local filter = { filter = "name", name = "air-scrubber" }
+local filter = { filter = "name", name = "atan-air-scrubber" }
```

I also noticed two compatibility leftovers:

- The Space Age pollution-filter cleaning recipe currently uses `organic` and
  `advanced-crafting`. Its previous `organic-or-chemistry` category corresponds
  to `categories = {"organic", "chemistry"}` in 2.1; that retains chemical-plant
  access instead of allowing ordinary advanced crafting machines.
- The Ash integration only checks `atan-ash`. The 2.1 continuation is
  `atan-ash-fork`, which retains the `atan-ash` item name. Adding
  `"? atan-ash-fork"` to the dependencies and accepting either mod ID in the
  existing Ash guard should restore the original Ash integration.

These findings are from inspecting the released ZIP. I have also confirmed the
unmodified package loads in Factorio 2.1.23. For ESIR's compatibility repair, native
fast replacement with a shared replacement group preserved a populated rare
scrubber's inventories, recipe, in-progress craft, result quality, damage and
script flags. Mining it afterwards returned all 12 original filters, including
the filter already consumed by the unfinished craft, plus the five existing used
filters and one rare scrubber. The same check passed after a real mid-craft
save/reload.

One caveat for a broader repair: the current handler destroys the entity before
replacement, so it should not be reused for already-running machines. Also,
`can_fast_replace` rejected these hidden variant identities in my test even
though actual native replacement succeeded. I verified the old entity was
actually replaced before treating the operation as successful. Energy still
obeys the target variant's native buffer capacity, so an over-capacity charge
cannot be retained merely by assigning `energy`.
