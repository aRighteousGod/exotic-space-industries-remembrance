# Sparse-profile refresh compatibility proposal

Status: the user approved this compatibility exception after reviewing the
native test findings. Applied in the late production performance pass; final
acceptance uses production runs with both candidate flags false.

Factorio 2.0.77 retires the observed short-flight stream before its next sparse
particle is due. This is native-test evidence, not a documented engine-source
claim. At 8x near minimum range and 16x at medium range, the new faster stream
therefore restarts once per attack and delivers half the intended direct damage.
Increasing cosmetic fade to 64 or using a short loop/default fade did not fix it.

The candidate changes only the acidthrower's internal refresh under 8x/16x:

| Profile | Attack refresh ticks | Fluid per refresh | Damaging particle interval |
| --- | --- | --- | --- |
| 8x | 32 -> 16 | 8 -> 4 | 16, unchanged |
| 16x | 64 -> 32 | 16 -> 8 | 32, unchanged |

Apply this **after** `turret_deliveries` in the late performance pass so the
existing stream timeout remains 48/96 respectively. Do not change damage,
stickers, buffer, radius, particle count or the other throwers' refresh behavior.

```lua
if name == "ei-acidthrower-turret" and factor >= 8 then
    attack.cooldown = attack.cooldown / 2
    attack.fluid_consumption = attack.fluid_consumption / 2
end
```

The isolated tests restore intended cadence and matched fluid/second within
the measurement window's boundary error. At 16x minimum range the old stream
already underdelivers, so this also restores that existing lost cadence:
direct damage is approximately doubled there, while unchanged corrosion means
combined damage increases by approximately one third in the normal unmodified
sulfuric-acid case. Record that correction separately from ordinary parity.

The alternative is to retain old travel/leading behavior at 8x/16x while keeping
the new liquid artwork. It preserves refresh declarations but gives up the
approved faster travel in those profiles. The normal Original profile and 2x/4x
do not need this exception.
