
-- this is the file to put all your custom logic functions into.
-- if you dont want to use the json based logic you can switch to a graph-based logic method.
-- the needed functions for that are in `/scripts/logic/graph_logic/logic_main.lua`.



-- function <name> (<parameters if needed>)
--     <actual code>
--     <indentations are just for readability>
-- end
--


-- Globals for Schedule I slot data (persistent after connection)
local randomize_customers = nil
local randomize_dealers = nil
local randomize_suppliers = nil
local randomize_level_unlocks = nil
local randomize_business_properties = nil
local randomize_cartel_influence = nil
local recipe_checks_count = 0
local cash_for_trash_count = 0

-- Clear handler: captures slot data when connected
Archipelago:AddClearHandler("schedule_i_slot_data_init", function(slot_data)
    print("ClearHandler fired! Slot data received.")

    -- Helper to safely read bool from top-level or options
    local function get_bool(val, fallback)
        if val == nil and slot_data.options then
            val = slot_data.options[fallback]
        end
        return (val == true or val == 1)
    end

    randomize_customers           = get_bool(slot_data.randomize_customers,          "randomize_customers")
    randomize_dealers             = get_bool(slot_data.randomize_dealers,            "randomize_dealers")
    randomize_suppliers           = get_bool(slot_data.randomize_suppliers,          "randomize_suppliers")
    randomize_level_unlocks       = get_bool(slot_data.randomize_level_unlocks,      "randomize_level_unlocks")
    randomize_business_properties = get_bool(slot_data.randomize_business_properties, "randomize_business_properties")
    randomize_cartel_influence    = get_bool(slot_data.randomize_cartel_influence,   "randomize_cartel_influence")
    randomize_sewer_key    = get_bool(slot_data.randomize_sewer_key,   "randomize_sewer_key")

    -- Numbers (default 0 if missing)
    recipe_checks_count = tonumber(slot_data.recipe_checks) or 0
    cash_for_trash_count = tonumber(slot_data.cash_for_trash) or 0

    -- Optional debug prints
    print("randomize_customers: " .. tostring(randomize_customers))
    print("randomize_dealers: " .. tostring(randomize_dealers))
    print("randomize_suppliers: " .. tostring(randomize_suppliers))
    print("randomize_level_unlocks: " .. tostring(randomize_level_unlocks))
    print("randomize_business_properties: " .. tostring(randomize_business_properties))
    print("randomize_cartel_influence: " .. tostring(randomize_cartel_influence))
    print("randomize_sewer_key: " .. tostring(randomize_sewer_key))
    print("recipe_checks: " .. recipe_checks_count)
    print("cash_for_trash: " .. cash_for_trash_count)

    Tracker:Update()
end)

-- ==================== BOOLEAN OPTION FUNCTIONS ====================

function hasRandomizeCustomers()           return randomize_customers           and 1 or 0 end
function hasNormalCustomers()              return (not randomize_customers)     and 1 or 0 end

function hasRandomizeDealers()             return randomize_dealers             and 1 or 0 end
function hasNormalDealers()                return (not randomize_dealers)       and 1 or 0 end

function hasRandomizeSuppliers()           return randomize_suppliers           and 1 or 0 end
function hasNormalSuppliers()              return (not randomize_suppliers)     and 1 or 0 end

function hasRandomLevels()                 return randomize_level_unlocks       and 1 or 0 end
function hasNormalLevels()                 return (not randomize_level_unlocks) and 1 or 0 end

function hasRandomBusiness()               return randomize_business_properties and 1 or 0 end
function hasNormalBusiness()               return (not randomize_business_properties) and 1 or 0 end

function hasRandomCartel()                 return randomize_cartel_influence    and 1 or 0 end
function hasNormalCartel()                 return (not randomize_cartel_influence) and 1 or 0 end

function hasRandomSewer()                 return randomize_sewer_key    and 1 or 0 end
function hasNormalSewer()                 return (not randomize_sewer_key) and 1 or 0 end

-- ==================== NUMERIC THRESHOLD FUNCTIONS ====================

-- "$hasEnoughRecipes|8" true if recipe_checks >= 8
function hasEnoughRecipes(target)
    target = tonumber(target) or 0
    return (recipe_checks_count >= target) and 1 or 0
end

-- "$hasEnoughTrash|30" true if cash_for_trash >= 30
function hasEnoughTrash(target)
    target = tonumber(target) or 0
    return (cash_for_trash_count >= target) and 1 or 0
end



-- ==================== REGION ACCESS ====================

-- Northtown is always accessible (starting region)

-- Westville
function canReachWestville()
    if hasNormalCustomers() == 1 then
        -- Normal customers requires level unlock flag logic
        if hasNormalLevels() == 1 then
            return 1  -- no extra requirement
        elseif hasRandomLevels() == 1 then
            return Tracker:ProviderCountForCode("westvilleregionunlock") > 0 and 1 or 0
        end
    else
        -- Randomized customers has no other requirements
        return 1
    end
    return 0
end

-- Downtown (requires Westville + new conditions)
function canReachDowntown()
    if canReachWestville() == 0 then return 0 end  -- must have Westville first

    if hasNormalCustomers() == 1 then
        -- Normal customers means cartel influence matters
        if hasRandomCartel() == 1 then
            -- Need 2 Cartel Influence from Westville
            return Tracker:ProviderCountForCode("cartelinfluencewestville") >= 2 and 1 or 0
        else
            return 1  -- no cartel needed
        end
    else
        -- Randomized customers ignore cartel influence, always accessible if Westville is
        return 1
    end
end

-- Docks (requires Downtown + Fertilizer only if levels randomized + cartel if applicable)
function canReachDocks()
    if canReachDowntown() == 0 then return 0 end

    -- Fertilizer check only when levels are randomized
    if hasRandomLevels() == 1 then
        if Tracker:ProviderCountForCode("fertilizerunlock") == 0 then return 0 end
    end

    -- Cartel influence check only when cartel is randomized AND customers are NOT randomized
    if hasRandomCartel() == 1 and hasNormalCustomers() == 1 then
        return Tracker:ProviderCountForCode("cartelinfluencedowntown") >= 7 and 1 or 0
    end

    return 1
end

-- Suburbia (requires Docks + cartel influence if applicable)
function canReachSuburbia()
    if canReachDocks() == 0 then return 0 end

    -- Cartel influence check only when cartel is randomized AND customers are NOT randomized
    if hasRandomCartel() == 1 and hasNormalCustomers() == 1 then
        return Tracker:ProviderCountForCode("cartelinfluencedocks") >= 7 and 1 or 0
    end

    return 1
end

-- Uptown (requires Suburbia + Drying Rack only if levels randomized + cartel if applicable)
function canReachUptown()
    if canReachSuburbia() == 0 then return 0 end

    -- Drying Rack check only when levels are randomized
    if hasRandomLevels() == 1 then
        if Tracker:ProviderCountForCode("dryingrackunlock") == 0 then return 0 end
    end

    -- Cartel influence check only when cartel is randomized AND customers are NOT randomized
    if hasRandomCartel() == 1 and hasNormalCustomers() == 1 then
        return Tracker:ProviderCountForCode("cartelinfluencesuburbia") >= 7 and 1 or 0
    end

    return 1
end



-- ==================== CUSTOMER COUNT FOR "MOVING UP" ====================

-- List of all customer unlock codes
local moving_up_customers = {
    "austinsteinerunlocked",
    "bethpennunlocked",
    "chloebowersunlocked",
    "donnamartinunlocked",
    "geraldinepoonunlocked",
    "jessiwatersunlocked",
    "kathyhendersonunlocked",
    "kylecooleyunlocked",
    "ludwigmeyerunlocked",
    "micklubbinunlocked",
    "mrsmingunlocked",
    "peggymyersunlocked",
    "peterfileunlocked",
    "samthompsonunlocked",
    "charlesrowlandunlocked",
    "deanwebsterunlocked",
    "dorislubbinunlocked",
    "georgegreeneunlocked",
    "jerrymonterounlocked",
    "joyceballunlocked",
    "keithwagnerunlocked",
    "kimdelaneyunlocked",
    "megcooleyunlocked",
    "trentshermanunlocked",
    "brucenortonunlocked",
    "elizabethhomleyunlocked",
    "eugenebuckleyunlocked",
    "gregfiggleunlocked",
    "jeffgilmoreunlocked",
    "jenniferriveraunlocked",
    "kevinoakleyunlocked",
    "louisfourierunlocked",
    "philipwentworthunlocked",
    "randycaulfieldunlocked",
    "lucypenningtonunlocked",
    "annachesterfieldunlocked",
    "billykramerunlocked",
    "crankyfrankunlocked",
    "genghisbarnunlocked",
    "javierperezunlocked",
    "kellyreynoldsunlocked",
    "lisagardenerunlocked",
    "maccooperunlocked",
    "marcobaroneunlocked",
    "melissawoodunlocked",
    "shermangilesunlocked",
    "alisonknightunlocked",
    "carlbundyunlocked",
    "chrissullivanunlocked",
    "denniskennedyunlocked",
    "hankstevensonunlocked",
    "haroldcoltunlocked",
    "jackknightunlocked",
    "jackiestevensonunlocked",
    "jeremywilkinsonunlocked",
    "karenkennedyunlocked",
    "fionahancockunlocked",
    "herbertbleuballunlocked",
    "irenemeadowsunlocked",
    "jenheardunlocked",
    "lilyturnerunlocked",
    "michaelboogunlocked",
    "pearlmooreunlocked",
    "rayhoffmanunlocked",
    "tobiaswentworthunlocked",
    "waltercusslerunlocked"
}

-- Returns 1 if player has at least 10 of the listed customers unlocked OR customers not randomized
function has10MovingUpCustomers()
    if hasRandomizeCustomers() == 1 then
        local count = 0
        for _, code in ipairs(moving_up_customers) do
            if Tracker:ProviderCountForCode(code) > 0 then
                count = count + 1
                if count >= 10 then return 1 end
            end
        end
        return 0
    else
        return 1  -- not randomized means auto-pass
    end
end


-- Dodgy Dealing: requires 10 Moving Up customers AND at least one of these three specific ones OR not randomized
function hasDodgyDealing()
    if hasRandomizeCustomers() == 1 then
        if has10MovingUpCustomers() == 0 then return 0 end
        
        -- One of the three special customers
        if Tracker:ProviderCountForCode("ludwigmeyerunlocked") > 0 or
           Tracker:ProviderCountForCode("bethpennunlocked") > 0 or
           Tracker:ProviderCountForCode("chloebowersunlocked") > 0 then
            return 1
        end
        return 0
    else
        return 1  -- not randomized means auto-pass
    end
end


-- Mixing Mania: true if hasDodgyDealing AND (randomized levels plus mixing station(s) with warehouse for Mk2) OR normal levels
function hasMixingMania()
    if hasDodgyDealing() == 0 then
        return 0
    end
    
    -- Mixing stations only required if levels are randomized
    if hasRandomLevels() == 1 then
        local station1_ok = Tracker:ProviderCountForCode("mixingstationunlock") > 0
        local station2_ok = Tracker:ProviderCountForCode("mixingstationmk2unlock") > 0
        
        if station1_ok or 
           (station2_ok and Tracker:ProviderCountForCode("warehouseaccess") > 0) then
            return 1
        end
        
        return 0
    end
    
    -- If levels are normal, auto-pass
    return 1
end


-- Wretched Hive: true if hasMixingMania AND (randomized levels plus warehouseaccess) OR normal levels
function hasWretchedHive()
    -- Must have Mixing Mania first
    if hasMixingMania() == 0 then
        return 0
    end
    
    -- Warehouse Access only required when levels are randomized
    if hasRandomLevels() == 1 then
        return Tracker:ProviderCountForCode("warehouseaccess") > 0 and 1 or 0
    end
    
    --If levels are normal, auto-pass
    return 1
end


-- Need Cook 1: requires hasWretchedHive AND one of these four paths
function hasNeedCook1()
    if hasWretchedHive() == 0 then
        return 0
    end

    if hasNormalSuppliers() == 1 and hasNormalCustomers() == 1 then
        return 1
    end

    if hasNormalSuppliers() == 1 and hasRandomizeCustomers() == 1 and 
       Tracker:ProviderCountForCode("megcooleyunlocked") > 0 then
        return 1
    end

    if hasNormalSuppliers() == 1 and hasRandomizeCustomers() == 1 and 
       Tracker:ProviderCountForCode("jerrymonterounlocked") > 0 then
        return 1
    end

    if hasRandomizeSuppliers() == 1 and 
       Tracker:ProviderCountForCode("shirleywattsunlocked") > 0 then
        return 1
    end

    return 0
end


-- Need Cook 2: requires hasNeedCook1 AND level requirement
function hasNeedCook2()
    -- Base requirement: previous mission
    if hasNeedCook1() == 0 then
        return 0
    end

    -- Level requirement
    if hasNormalLevels() == 1 then
        return 1  -- normal levels means auto-pass
    end

    -- Randomized levels requires all four lab items
    if hasRandomLevels() == 1 then
        local chem_ok = Tracker:ProviderCountForCode("chemistrystationunlock") > 0
        local oven_ok = Tracker:ProviderCountForCode("labovenunlock") > 0
        local acid_ok = Tracker:ProviderCountForCode("acidunlock") > 0
        local phos_ok = Tracker:ProviderCountForCode("phosphorusunlock") > 0
        return (chem_ok and oven_ok and acid_ok and phos_ok) and 1 or 0
    end

    return 0
end


-- List of the 10 specific customers required for Unfavourable Agreement
local unfavourable_customers = {
    "charlesrowlandunlocked",
    "deanwebsterunlocked",
    "dorislubbinunlocked",
    "georgegreeneunlocked",
    "jerrymonterounlocked",
    "joyceballunlocked",
    "kimdelaneyunlocked",
    "megcooleyunlocked",
    "trentshermanunlocked",
    "keithwagnerunlocked"
}

-- Unfavourable Agreement: requires hasNeedCook2 AND customer requirement
function hasUnfavourableAgreement()
    -- Base requirement: previous mission
    if hasNeedCook2() == 0 then
        return 0
    end

    -- Customer requirement
    if hasNormalCustomers() == 1 then
        return 1  -- normal customers meams auto-pass
    end

    if hasRandomizeCustomers() == 1 then
        local count = 0
        for _, code in ipairs(unfavourable_customers) do
            if Tracker:ProviderCountForCode(code) > 0 then
                count = count + 1
                if count >= 5 then
                    return 1
                end
            end
        end
        return 0
    end

    return 0
end


-- Finish Job 1: requires hasUnfavourableAgreement AND (normal cartel OR randomized cartel + 7 suburbia influence)
function hasFinishJob1()
    if hasUnfavourableAgreement() == 0 then
        return 0
    end

    if hasNormalCartel() == 1 then
        return 1  -- normal cartel means auto-pass
    end

    if hasRandomCartel() == 1 then
        return Tracker:ProviderCountForCode("cartelinfluencesuburbia") >= 7 and 1 or 0
    end

    return 0
end


-- Finish Job 2: requires hasFinishJob1 AND all three conditional branches
function hasFinishJob2()
    if hasFinishJob1() == 0 then
        return 0
    end

    -- Suppliers
    local suppliers_ok = false
    if hasNormalSuppliers() == 1 then
        suppliers_ok = true
    elseif hasRandomizeSuppliers() == 1 then
        suppliers_ok = Tracker:ProviderCountForCode("salvadormorenounlocked") > 0
    end
    if not suppliers_ok then return 0 end

    -- Levels
    local levels_ok = false
    if hasNormalLevels() == 1 then
        levels_ok = true
    elseif hasRandomLevels() == 1 then
        local gas_ok = Tracker:ProviderCountForCode("gasolineunlock") > 0
        local cauldron_ok = Tracker:ProviderCountForCode("cauldronunlock") > 0
        levels_ok = (gas_ok and cauldron_ok)
    end
    if not levels_ok then return 0 end

    -- Customers
    local customers_ok = false
    if hasNormalCustomers() == 1 then
        customers_ok = true
    else
        local billy = Tracker:ProviderCountForCode("billykramerunlocked") > 0
        local sam   = Tracker:ProviderCountForCode("samthompsonunlocked") > 0
        local mac   = Tracker:ProviderCountForCode("maccooperunlocked") > 0
        local javier = Tracker:ProviderCountForCode("javierperezunlocked") > 0

        -- Billy AND Sam AND (Mac OR Javier)
        customers_ok = (billy and sam and (mac or javier))
    end
    if not customers_ok then return 0 end

    return 1
end