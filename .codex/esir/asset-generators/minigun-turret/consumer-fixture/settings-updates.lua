local config = require('test-config')
if not config.standalone then
    local setting = assert(data.raw['bool-setting']['ei-ballistic-divergence'])
    setting.default_value, setting.forced_value, setting.hidden = config.ballistic, config.ballistic, true
    local preset = assert(data.raw['string-setting']['ei-ballistic-divergence-preset'])
    preset.default_value, preset.allowed_values = 'tempered', {'tempered'}
end
