-- Semantic menu icons, independent of the active provider. Missing art stays empty.
local M={}
local art={Q='/LHO_LeeSinQ.png',W='/LHO_LeeSinW.png',E='/LHO_LeeSinE.png',R='/LHO_LeeSinR.png',
    passive='/LHO_Passive.png',hero='/LHO_LeeSin.png',guide='/LHO_Guide.png',ward='/3340.png',
    target='/Gamsteron_TargetSelector.png',move='/Gamsteron_Orbwalker.png',draw='/Gamsteron_Drawings.png',
    smite='/Gamsteron_Spell_SummonerSmite.png',flash='/Gamsteron_Spell_SummonerFlash.png',
    ignite='/Gamsteron_Spell_SummonerDot.png',potion='/2003.png',minion='/Gamsteron_Minion.png',
    items='/ActivatorScriptLogo.png',cleanse='/3140.png',shield='/3190.png',slow='/3143.png',speed='/3142.png'}
local exact={Controls='hero',Combat='target',Harass='Q',Assists='W',Insec='R',Wave='minion',
    LastHit='minion',Jungle='smite',Wardjump='ward',Farming='move',SmiteItems='items',Drawings='draw',Guide='guide',
    Status='hero',Damage='target',WardRange='ward',Abilities='passive',Chase='move',Finishes='R',
    Targeting='target',Resources='ward',Flash='flash',Potions='potion',Items='items',Smite='smite',
    cursorKey='R',allyKey='R',insecPreviewKey='R',wardKey='ward',autoJungleKey='move',qAssistKey='Q',
    smiteKey='smite',secureKey='smite',guideKey='guide',guideOpen='guide',guidePage='guide',
    comboPassive='passive',comboBurst='target',comboConserveR='R',comboKickFollow='R',comboIsolate='R',
    multi='R',multiHits='R',collateralKills='R',autoMultiR='R',defensiveR='R',
    idleDefense='W',reserveW='W',shieldHP='W',allyShieldHP='W',expiryW='W',expiryE='E',
    itemCleanse='cleanse',itemShield='shield',itemSlow='slow',itemSpeed='speed',itemCleave='items',
    itemTargeted='items',items='items',damageItems='items',damageSummoners='ignite',
    drawQRange='Q',drawWRange='W',drawERange='E',drawRRange='R',drawWardRange='ward',
    drawHUD='hero',drawWard='ward',drawInsec='R',drawInsecTolerance='R',draw='draw',enabled='hero',
    qOnlySelected='Q',hitchance='Q',q2Safety='Q',clearKrugE='E',clearQTiming='Q',
    farmPreserveQ='Q',farmQTravel='Q',farmQBlind='Q',farmQRespawn='Q',farmQAdjust='Q',
    jungleQ2MeleeOnly='Q',jungleQ2RangeScale='Q',waveSoften='E',
    insecQ='Q',insecBridges='Q',insecW='W',insecChains='ward',insecCloseWard='ward',
    insecLandingMargin='ward',insecMouseTarget='target',insecMouseRadius='target',insecTrackAlly='target',
    aimLock='target',insecWalk='move',insecOrbwalk='move',comboWard='ward',comboWardRetry='ward',
    comboWardGain='ward',comboWalkWait='move',comboChaseE2='E',wardFollowCursor='move',wardApproach='move',
    wardAssist='ward',reuseRadius='ward',assistRadius='ward',wardWalkRange='move',
    comboIgnite='ignite',igniteExecute='ignite',autoJungle='move',openingRoute='move',
    farmKite='move',farmKiteDistance='move',farmKiteLeash='move',damageBars='target'}
function M.new()
    local cache={}
    local function resolve(symbol)
        local path=art[symbol];if not path then return nil end
        if cache[path]~=nil then return cache[path] or nil end
        local found=false
        if SPRITE_PATH and type(FileExist)=='function' then
            local base=SPRITE_PATH;if not base:match('[/\\]$') then base=base..'/' end
            local ok,exists=pcall(FileExist,base..'MenuElement'..path);found=ok and exists
        end
        cache[path]=found and path or false;return cache[path] or nil
    end
    return function(key)
        local symbol=exact[key] or (art[key] and key)
        if not symbol then
            if key:match('^potion') then symbol='potion'
            elseif key:match('^smite') or key=='autosmite' then symbol='smite'
            elseif key:match('^insecFlash') then symbol='flash'
            else
                for _,prefix in ipairs({'combo','harass','kill','wave','last','jungle','autoClear','damage'}) do
                    local spell=key:match('^'..prefix..'([QWER])%d?$')
                    if spell then symbol=spell;break end
                end
            end
        end
        return resolve(symbol)
    end
end
return M
