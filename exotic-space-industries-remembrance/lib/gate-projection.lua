-- blueprint: .codex/esir/blueprints/gate.md#contract
-- Deterministic, resumable single-item simulation. Operates only on plain scenario data.
local calc = require("lib/gate-calculations")
local model = {}

---@class GateEstimateScenario
---@field item string
---@field quality string|nil Sender quality prototype name, retained for pinned-input repair.
---@field from string|nil Sending planet name.
---@field to string|nil Receiving planet name.
---@field span_ratio number|nil Fixed snapshot span, including an unresolved receiver's zero.
---@field batch integer Maximum offered deposit, not a transfer-size override.
---@field stack_size integer
---@field slots integer
---@field weight number
---@field multiplier number Distance multiplier.
---@field quality_multiplier number
---@field energy number Initial joules.
---@field capacity number
---@field input_limit number Joules per tick, as on the native EEI.
---@field power number Available watts.
---@field rate number Offered items per second.
---@field stress number
---@field saturation number
---@field cooldown number Initial remaining ticks.
---@field service integer Fixed sender service interval, ticks.
---@field horizon integer Seconds.

---@param scenario GateEstimateScenario
---@return table job Serializable resumable state; never contains world entities.
function model.new(scenario)
    local job = {scenario=scenario, tick=0, energy=scenario.energy, stress=scenario.stress,
        saturation=scenario.saturation, deadline=scenario.cooldown, upstream=0, cargo=0,
        stacks={}, delivered=0, offered=0, transfer_j=0, upkeep_j=0, charged_j=0,
        residue=0, residue_progress=0, transfers=0, interval=0,
        waits={cooldown=0,power=0,receiver=0}, minimum_energy=scenario.energy,
        maximum_stress=scenario.stress, bins={}, bin_ticks=math.max(1,math.ceil(scenario.horizon*60/240))}
    job.locked=scenario.energy<calc.low_power or scenario.cooldown>0
    return job
end

local function sample(job)
    local s=job.scenario
    local index=math.min(240,math.floor((job.tick-1)/job.bin_ticks)+1)
    local bin=job.bins[index]
    if not bin then
        bin={from=(job.tick-1)/60,to=job.tick/60,min={},max={},last={},
            transfer_start=job.transfer_j,upkeep_start=job.upkeep_j,delivered_start=job.delivered}
        job.bins[index]=bin
    end
    bin.to=job.tick/60
    local values={job.energy/1e9,job.stress,job.saturation,math.max(0,job.deadline-job.tick)/60,
        job.interval/60,job.upstream,job.cargo}
    for i,value in ipairs(values) do
        bin.min[i]=math.min(bin.min[i] or value,value)
        bin.max[i]=math.max(bin.max[i] or value,value)
        bin.last[i]=value
    end
    local seconds=math.max(1/60,bin.to-bin.from)
    bin.rate=(job.delivered-bin.delivered_start)/seconds
    bin.transfer_w=(job.transfer_j-bin.transfer_start)/seconds/1e6
    bin.upkeep_w=(job.upkeep_j-bin.upkeep_start)/seconds/1e6
    bin.offered=s.rate
end

---@param job table
---@param budget integer Maximum simulated ticks.
---@return boolean complete
function model.advance(job,budget)
    local s=job.scenario
    for _=1,math.min(budget,s.horizon*60-job.tick) do
        local tick=job.tick+1
        -- Bin counters precede this tick's transfers, including a transfer on its first tick.
        if (tick-1)%job.bin_ticks==0 then
            job.bins[math.floor((tick-1)/job.bin_ticks)+1]={from=(tick-1)/60,to=tick/60,min={},max={},last={},
                transfer_start=job.transfer_j,upkeep_start=job.upkeep_j,delivered_start=job.delivered}
        end
        job.tick=tick
        local charge=math.min(s.power/60,s.input_limit,math.max(0,s.capacity-job.energy))
        job.energy=job.energy+charge;job.charged_j=job.charged_j+charge
        job.upstream=job.upstream+s.rate/60;job.offered=job.offered+s.rate/60
        if not job.locked then
            local deposit=math.min(math.floor(job.upstream+1e-9),s.batch,s.slots*s.stack_size-job.cargo)
            local remaining=deposit
            for i=1,s.slots do
                if remaining<=0 then break end
                local count=job.stacks[i] or 0
                local amount=math.min(remaining,s.stack_size-count)
                job.stacks[i]=count+amount;remaining=remaining-amount
            end
            job.cargo=job.cargo+deposit;job.upstream=math.max(0,job.upstream-deposit)
        end
        -- Receiver refresh precedes sender service in the native sixteen-slot dispatcher.
        if tick%16==0 then job.saturation=math.max(0,job.saturation-16/60*calc.saturation_decay) end
        if tick%s.service==0 then
            local previous=tick-s.service
            local ending,drain=calc.elapsed(job.stress,s.service,
                math.max(0,math.min(tick,job.deadline)-previous),s.quality_multiplier)
            if job.energy>=calc.low_power then
                local paid=math.min(job.energy,drain)
                job.energy=job.energy-paid;job.upkeep_j=job.upkeep_j+paid
            end
            job.stress=ending
            job.locked=job.energy<calc.low_power or job.deadline>tick
            job.unaffordable=false
            if not job.locked and job.saturation<100 then
                for i=1,s.slots do
                    local count=job.stacks[i] or 0
                    if count>0 then
                        local q=calc.quote(count*s.weight,count,s.multiplier,s.quality_multiplier,s.span_ratio)
                        if job.energy>=q.energy_j then
                            job.energy=job.energy-q.energy_j;job.transfer_j=job.transfer_j+q.energy_j
                            job.stacks[i]=0;job.cargo=job.cargo-count;job.delivered=job.delivered+count
                            local stress,cooldown=calc.after_transfer(job.stress,q)
                            job.stress=stress;job.deadline=tick+cooldown;job.locked=true
                            job.saturation=math.min(100,job.saturation+q.saturation_delta)
                            job.residue_progress=job.residue_progress+q.residue_delta
                            local residue=math.floor(job.residue_progress/calc.residue_threshold)
                            job.residue=job.residue+residue;job.residue_progress=job.residue_progress-residue*calc.residue_threshold
                            if job.last_transfer then job.interval=tick-job.last_transfer end
                            job.last_transfer=tick;job.transfers=job.transfers+1
                            break
                        else job.unaffordable=true end
                    end
                end
            end
        end
        if job.cargo>0 or job.upstream>=1 then
            if job.deadline>tick then job.waits.cooldown=job.waits.cooldown+1 end
            if job.energy<calc.low_power or job.unaffordable then job.waits.power=job.waits.power+1 end
            if job.saturation>=100 then job.waits.receiver=job.waits.receiver+1 end
        end
        job.minimum_energy=math.min(job.minimum_energy,job.energy)
        job.maximum_stress=math.max(job.maximum_stress,job.stress)
        sample(job)
    end
    job.complete=job.tick>=s.horizon*60
    return job.complete
end

return model
