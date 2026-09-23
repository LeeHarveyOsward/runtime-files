-- Local deployment calibration recorded 2026-09-08: game.cfg renders at
-- 5120x2160, Game.Resolution reports 4096x1728, and native posMM uses render
-- pixels. Apply only to out-of-bounds points with this exact API resolution.
-- Other resolutions retain native coordinates and require new evidence.
return {apiWidth=4096,apiHeight=1728,renderWidth=5120,renderHeight=2160}
