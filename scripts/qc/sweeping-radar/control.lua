local config=require("test-config")
if config.fixture=="gate" then require("gate")
elseif config.fixture=="quality" then require("quality")
elseif config.fixture=="energy-migration" then require("energy-migration")
elseif config.fixture=="benchmark" then require("benchmark")
elseif config.fixture=="persistence" then require("persistence")
elseif config.fixture=="generation-persistence" then require("generation-persistence")
elseif config.fixture=="visual" then require("visual")
else require("acceptance") end
