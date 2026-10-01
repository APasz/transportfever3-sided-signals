global record SidedSignals
    type ConstructionParams = {string: number}

    record ResultModel
        id: string | nil
        transf: {number} | nil
    end

    record ResultEdgeModel
        edgeOffset: number | nil
        model: ResultModel | nil
    end

    record ResultSignal
        type: string
    end

    record SignalResult
        signal: ResultSignal | nil
        edgeModels: {ResultEdgeModel} | nil
    end

    record ModelCentre
        x: number
        y: number
        z: number
    end

    record LateralCorrection
        left: number
        right: number
        configured: boolean
    end

    record ModelAlignment
        centre: ModelCentre
        lateralCorrection: LateralCorrection
        ignore: boolean
    end

    record MetadataConfig
        ignore: boolean
        lateralCorrection: LateralCorrection | nil
    end

    record ModelOverride
        expectedMinY: number
        expectedMaxY: number
        lateralCorrection: LateralCorrection
    end

    record Core
        ADVANCED_ADJUSTMENTS_PARAM_KEY: string
        ADVANCED_ADJUSTMENTS_ON_INDEX: integer
        SIDE_KEY: string
        SIDE_OFFSET_KEY: string
        LONGITUDINAL_OFFSET_KEY: string
        HEIGHT_OFFSET_KEY: string
        YAW_OFFSET_KEY: string
        PITCH_OFFSET_KEY: string
        ROLL_OFFSET_KEY: string
        MODE_KEY: string
        PARAM_GROUP: string
        PARAM_SCRIPT: string
        HAS_INJECTED_SIDE_CAPTURE_KEY: string
        MODEL_ALIGNMENTS_CAPTURE_KEY: string
        METADATA_KEY: string
        METADATA_VERSION: integer

        SIDE_ORIGINAL_INDEX: integer
        SIDE_LEFT_INDEX: integer
        SIDE_RIGHT_INDEX: integer
        MODE_ORIGINAL_INDEX: integer
        MODE_SIGNAL_INDEX: integer
        MODE_WAYPOINT_INDEX: integer

        hasMarker: function(string, string): boolean
        isFiniteNumber: function(any): boolean
        finiteNumberOr: function(any, number): number
        formatMetres: function(number): string
        formatDegrees: function(number): string
        normalizeResourceName: function(string): string
        hasParam: function({api.type.ScriptParam}, string): boolean
    end

    record Metadata
        read: function(any, string): MetadataConfig
        resolveLateralCorrection: function(
            string,
            string,
            BoundingInfo,
            MetadataConfig
        ): LateralCorrection
    end

    record Construction
        modify: function(
            string,
            api.type.ConstructionDesc,
            boolean
        ): api.type.ConstructionDesc
    end

    record Alignment
        findCaptured: function(any, string): ModelAlignment | nil
        warnMissing: function(string)
        prepareSignalConstructions: function()
    end

    record Placement
        modifyScript: function(string, any, boolean): any
    end
end
