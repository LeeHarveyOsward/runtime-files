-- Select the same total order as the historical full sort. Fairness is captured
-- when candidates become executable, before any dispatch updates scope.last.
return function(candidates)
    local best,index
    for i,a in ipairs(candidates)do
        local b=best
        if not b or a.effective>b.effective or a.effective==b.effective and (
            a.record.expires<b.record.expires or a.record.expires==b.record.expires and (
                a.selectionLast<b.selectionLast or a.selectionLast==b.selectionLast and a.record.id<b.record.id)) then
            best,index=a,i
        end
    end
    return best,index
end
