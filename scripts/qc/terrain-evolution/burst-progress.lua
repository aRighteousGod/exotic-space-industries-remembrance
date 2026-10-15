-- Pure fixture helper: fixed accepted thermal-request cohort, no runtime writes.
-- Capture during frozen burst setup; summarize once after the timer stops.
local model={}
function model.new()
    return {records={},ids={}}
end
function model.capture(cohort,record)
    assert(record and record.id and record.cause=="thermal","Expected accepted thermal descriptor")
    assert(not cohort.ids[record.id],"Duplicate accepted fixture descriptor")
    assert(type(record.radius)=="number","Expected frozen patch radius")
    local work_size=(record.radius*2+1)^2
    local offset=record.offset or 0
    assert(offset>=0 and offset<=work_size,"Invalid initial patch offset")
    cohort.ids[record.id]=true
    cohort.records[#cohort.records+1]={record=record,id=record.id,offset=offset,work_size=work_size}
end
function model.summarize(cohort,pending)
    local result={initial=#cohort.records,retained=0,advanced=0,completed_retired=0,
        retired_early=0,regressed=0,invalid_descriptor=0,offset_steps=0,unchanged=0,
        replacements=0,new_pending=0,examples={}}
    for _,initial in ipairs(cohort.records) do
        local record=initial.record
        local live=pending.items[pending.index[initial.id] or 0]
        local retained=live==record
        local offset=record.offset or 0
        local invalid=record.id~=initial.id or record.cause~="thermal" or offset>initial.work_size
        if retained then result.retained=result.retained+1
        elseif live then result.replacements=result.replacements+1 end
        if invalid then result.invalid_descriptor=result.invalid_descriptor+1 end
        if offset<initial.offset then result.regressed=result.regressed+1 end
        if offset>initial.offset then
            result.advanced=result.advanced+1
            result.offset_steps=result.offset_steps+math.min(offset,initial.work_size)-initial.offset
        elseif retained then result.unchanged=result.unchanged+1 end
        if not retained then
            if offset>=initial.work_size then result.completed_retired=result.completed_retired+1
            else
                result.retired_early=result.retired_early+1
                if #result.examples<8 then result.examples[#result.examples+1]={id=initial.id,offset=offset,work_size=initial.work_size,replaced=live~=nil} end
            end
        end
    end
    result.new_pending=#pending.items-result.retained
    -- Advancing protected/ineligible cells is queue work, not proof of tile writes.
    -- Disappearance without a fully visited frozen patch is never called progress.
    result.pass=result.initial>0 and (result.offset_steps>0 or result.completed_retired>0)
        and result.retired_early==0 and result.regressed==0 and result.invalid_descriptor==0
    return result
end
return model
