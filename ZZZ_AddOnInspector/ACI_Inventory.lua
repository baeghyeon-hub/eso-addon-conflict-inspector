----------------------------------------------------------------------
-- ACI_Inventory.lua — GetAddOnManager 기반 정적 메타데이터 수집
----------------------------------------------------------------------

function ACI.CollectMetadata()
    local manager = GetAddOnManager()
    if not manager then
        return { error = "GetAddOnManager() returned nil" }
    end

    local numAddons = manager:GetNumAddOns()
    local addons = {}
    local outOfDateCount = 0
    local libraryCount = 0
    local enabledCount = 0

    for i = 1, numAddons do
        local name, title, author, description, enabled, state, isOutOfDate, isLibrary
            = manager:GetAddOnInfo(i)

        local version  = manager:GetAddOnVersion(i)
        local rootPath = manager:GetAddOnRootDirectoryPath(i)
        local numDeps  = manager:GetAddOnNumDependencies(i)

        local deps = {}
        for d = 1, numDeps do
            if manager.GetAddOnDependencyInfo then
                local depName, depActive = manager:GetAddOnDependencyInfo(i, d)
                table.insert(deps, { name = depName, active = depActive })
            end
        end

        local svDiskMB = nil
        if manager.GetUserAddOnSavedVariablesDiskUsageMB then
            svDiskMB = manager:GetUserAddOnSavedVariablesDiskUsageMB(i)
        end

        if enabled then
            enabledCount = enabledCount + 1
            if isOutOfDate then outOfDateCount = outOfDateCount + 1 end
            if isLibrary then libraryCount = libraryCount + 1 end
        end

        table.insert(addons, {
            index          = i,
            name           = name,
            title          = title,
            author         = author,
            description    = description,
            enabled        = enabled,
            state          = state,
            isOutOfDate    = isOutOfDate,
            isLibrary      = isLibrary,
            version        = version,
            rootPath       = rootPath,  -- 테이블 대입 시 순수 Lua string으로 변환됨
            loadOrderIndex = ACI.loadOrderMap[name],  -- EVENT_ADD_ON_LOADED 순서
            numDeps        = numDeps,
            deps           = deps,
            svDiskMB       = svDiskMB,
        })
    end

    -- 현재 게임 API 버전 기록
    local currentAPI = GetAPIVersion and GetAPIVersion() or nil

    return {
        numAddons      = numAddons,
        enabledCount   = enabledCount,
        libraryCount   = libraryCount,
        outOfDateCount = outOfDateCount,
        currentAPI     = currentAPI,
        addons         = addons,
        managerMethods = ACI.EnumerateMethods(manager),
    }
end
