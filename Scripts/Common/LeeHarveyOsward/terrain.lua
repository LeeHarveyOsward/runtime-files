local T=require('ChampionMobility.terrain')(require('lho.util'),require('lho.navigation'))
local new=T.new
T.new=function(ctx)return new(ctx,_G.LHO_Terrain)end
return T
