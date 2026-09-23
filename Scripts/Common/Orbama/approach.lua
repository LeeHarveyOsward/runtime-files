-- Explicit target-attack order used to approach during attack cooldown.
-- It does not claim an attack started: only native attack evidence may do that.
return function(env)
    return function(record)
        local orb=env.orb();local target=record.target
        if not orb:IsEnabled() or not orb.AttackEnabled or not orb.MovementEnabled
            or not orb.Menu.AttackEnabled:Value() or not orb.Menu.MovementEnabled:Value()
            or env.isDown(17) or env.isDown(18) or not orb.CanAttackC()
            or not env.canAttack() or not orb:CanMove() or orb:IsAutoAttacking() then record.reason='approach_attack_or_movement_gate';return false end
        if not target or not target.valid or not target.visible or target.dead or target.health<=0
            or not target.pos or not target.pos:To2D().onScreen or not env.targetable(target) then record.reason='approach_target_unavailable';return false end
        local args={Target=target,Process=true,Approach=true}
        for _,fn in ipairs(orb.OnPreAttackCb) do fn(args) end
        -- An approach contract belongs to this exact object. A retargeting hook
        -- must submit a fresh intent instead of silently chasing another unit.
        if not args.Process or args.Target~=target then record.reason='approach_pre_attack_hook';return false end
        if not env.send(target,record) then return false end
        orb.LastTarget=target
        return true
    end
end
