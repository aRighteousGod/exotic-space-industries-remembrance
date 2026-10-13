-- QC-only cosmetic variants; every one keeps the canonical attack payload.
if require("test-config").origin_variant_set=="short" then
    return {
        {name="short-30",width=30},
        {name="short-34",width=34},
        {name="short-36",width=36},
        {name="short-back",width=32,shift=-0.75/32},
        {name="short-forward",width=32,shift=0.75/32},
        {name="short-no-crop",width=32,no_crop=true},
        {name="full-no-crop",width=64,no_crop=true},
    }
end
return {
    {name="full-original",width=64},
    {name="full-forward-ribbon",width=64,shift=16/32},
    {name="full-forward-origin",width=64,launch=16/32},
}
