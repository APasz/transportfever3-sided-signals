local OVERRIDES: {string: SidedSignals.ModelOverride} = {
    ["yomiti1225_railway_signal::/infrastructure/signal/japanese_signal.mdl"] = {
        expectedMinY = 2.46455,
        expectedMaxY = 3.4304,
        lateralCorrection = {
            left = 0,
            right = -0.895, -- Published bounds sit outward of the visible mast.
            configured = true,
        },
    },
}

return OVERRIDES
