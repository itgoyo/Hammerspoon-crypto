-- -----------------------------------------------------------------------
--                    ** Crypto Price Menubar Module **                --
-- -----------------------------------------------------------------------

local obj = {}
obj.__index = obj

-- 模块信息
obj.name = "CryptoPrice"
obj.version = "1.0"
obj.author = "User"

-- 私有变量
local menubar = nil
local timer = nil
local config = nil
local priceData = nil

-- 加载配置文件
local function loadConfig()
    local configFile = hs.configdir .. "/crypto-config.lua"
    if hs.fs.attributes(configFile) then
        local success, loadedConfig = pcall(dofile, configFile)
        if success then
            return loadedConfig
        else
            hs.alert.show("配置文件加载失败，使用默认配置")
        end
    else
        hs.alert.show("配置文件未找到，使用默认配置")
    end
    
    -- 默认配置
    return {
        apiProvider = "coingecko",
        coingecko = {
            coins = {"bitcoin", "ethereum", "binancecoin"},
            currency = "usd",
            apiKey = ""
        },
        dexscreener = {
            tokens = {"BTC", "ETH", "BNB"},
            preferredChains = {"ethereum", "bsc", "polygon"}
        },
        refreshInterval = 60,
        showIcon = true,
        displayFormat = "compact"
    }
end

-- 移除末尾的零
local function removeTrailingZeros(str)
    if str:find("%.") then
        str = str:gsub("0+$", "")  -- 移除末尾的零
        str = str:gsub("%.$", "")  -- 移除末尾的小数点
    end
    return str
end

-- 格式化价格显示
local function formatPrice(price)
    if not price or price <= 0 then
        return "0"
    end
    
    local result
    if price >= 1000000 then
        result = string.format("%.2f", price / 1000000)
        return removeTrailingZeros(result) .. "M"
    elseif price >= 1000 then
        result = string.format("%.0f", price)
        return result
    elseif price >= 100 then
        result = string.format("%.1f", price)
        return removeTrailingZeros(result)
    elseif price >= 1 then
        result = string.format("%.2f", price)
        return removeTrailingZeros(result)
    elseif price >= 0.01 then
        result = string.format("%.4f", price)
        return removeTrailingZeros(result)
    elseif price >= 0.0001 then
        result = string.format("%.6f", price)
        return removeTrailingZeros(result)
    elseif price >= 0.00000001 then
        -- 对于非常小的价格，使用科学计数法
        return string.format("%.2e", price)
    else
        -- 对于极小的价格，显示前几位有效数字
        local str = string.format("%.12f", price)
        local leadingZeros = 0
        local i = 3 -- 跳过 "0."
        while i <= #str and str:sub(i, i) == "0" do
            leadingZeros = leadingZeros + 1
            i = i + 1
        end
        
        if leadingZeros >= 4 then
            -- 如果有4个或更多前导零，显示为 0.0(4)123 格式
            local significantDigits = str:sub(i, i + 2) -- 取3位有效数字
            return string.format("0.0(%d)%s", leadingZeros, significantDigits)
        else
            result = string.format("%.8f", price)
            return removeTrailingZeros(result)
        end
    end
end

-- 为菜单显示提供更详细的价格格式
local function formatPriceDetailed(price)
    if not price or price <= 0 then
        return "0"
    end
    
    local result
    if price >= 1000000 then
        result = string.format("%.2f", price / 1000000)
        return removeTrailingZeros(result) .. " M"
    elseif price >= 1000 then
        result = string.format("%.2f", price)
        return removeTrailingZeros(result)
    elseif price >= 1 then
        result = string.format("%.4f", price)
        return removeTrailingZeros(result)
    elseif price >= 0.000001 then
        result = string.format("%.8f", price)
        return removeTrailingZeros(result)
    else
        -- 对于极小的价格，先尝试显示有效数字格式
        local str = string.format("%.15f", price)
        local leadingZeros = 0
        local i = 3 -- 跳过 "0."
        while i <= #str and str:sub(i, i) == "0" do
            leadingZeros = leadingZeros + 1
            i = i + 1
        end
        
        if leadingZeros >= 6 then
            -- 如果前导零太多，使用科学计数法
            return string.format("%.3e", price)
        else
            -- 显示足够的小数位数
            local significantDigits = str:sub(i, i + 4) -- 取5位有效数字
            -- 移除有效数字末尾的零
            significantDigits = significantDigits:gsub("0+$", "")
            return string.format("0.0(%d)%s", leadingZeros, significantDigits)
        end
    end
end

-- 获取货币符号
local function getCoinSymbol(coinId)
    local symbols = {
        bitcoin = "BTC",
        ethereum = "ETH",
        binancecoin = "BNB",
        cardano = "ADA",
        solana = "SOL",
        polkadot = "DOT",
        chainlink = "LINK",
        litecoin = "LTC",
        ["usd-coin"] = "USDC",
        ripple = "XRP"
    }
    return symbols[coinId] or coinId:upper():sub(1, 3)
end

-- 从 CoinGecko API 获取价格
local function fetchCoinGeckoPrice(coinIds, currency, callback)
    local url = "https://api.coingecko.com/api/v3/simple/price?ids=" .. 
                table.concat(coinIds, ",") .. 
                "&vs_currencies=" .. currency .. 
                "&include_24hr_change=true"
    
    hs.http.asyncGet(url, nil, function(status, body, headers)
        if status == 200 then
            local success, data = pcall(hs.json.decode, body)
            if success and data then
                callback(true, data)
            else
                callback(false, "解析价格数据失败")
            end
        else
            callback(false, "获取价格数据失败，状态码: " .. tostring(status))
        end
    end)
end

-- 从 DexScreener API 获取价格
local function fetchDexScreenerPrice(tokens, preferredChains, callback)
    local results = {}
    local completed = 0
    local totalTokens = #tokens
    
    if totalTokens == 0 then
        callback(false, "没有配置代币")
        return
    end
    
    for i, token in ipairs(tokens) do
        local url = "https://api.dexscreener.com/latest/dex/search?q=" .. 
                    hs.http.encodeForQuery(token)
        
        hs.http.asyncGet(url, nil, function(status, body, headers)
            completed = completed + 1
            
            if status == 200 then
                local success, data = pcall(hs.json.decode, body)
                if success and data and data.pairs then
                    -- 寻找最佳匹配的交易对
                    local bestPair = nil
                    local bestScore = 0
                    
                    for _, pair in ipairs(data.pairs) do
                        local score = 0
                        
                        -- 检查代币名称匹配度 (提高权重)
                        if pair.baseToken and pair.baseToken.symbol then
                            local baseSymbol = pair.baseToken.symbol:upper()
                            local searchToken = token:upper()
                            
                            -- 完全匹配给最高分
                            if baseSymbol == searchToken then
                                score = score + 100
                            -- 如果搜索BTC，优先WBTC等包装版本
                            elseif searchToken == "BTC" and (baseSymbol == "WBTC" or baseSymbol == "BTCB") then
                                score = score + 80
                            -- 如果搜索ETH，优先WETH等包装版本
                            elseif searchToken == "ETH" and (baseSymbol == "WETH" or baseSymbol == "BETH") then
                                score = score + 80
                            -- 部分匹配
                            elseif baseSymbol:find(searchToken) then
                                score = score + 30
                            end
                        end
                        
                        -- 检查是否在首选链上
                        if preferredChains then
                            for _, chain in ipairs(preferredChains) do
                                if pair.chainId == chain then
                                    score = score + 20
                                    break
                                end
                            end
                        end
                        
                        -- 检查流动性 (提高权重)
                        if pair.liquidity and pair.liquidity.usd then
                            local liquidityScore = math.min(pair.liquidity.usd / 500000, 15)
                            score = score + liquidityScore
                        end
                        
                        -- 检查24小时交易量
                        if pair.volume and pair.volume.h24 then
                            local volumeScore = math.min(pair.volume.h24 / 100000, 10)
                            score = score + volumeScore
                        end
                        
                        -- 优先选择价格合理的交易对 (过滤掉明显错误的价格)
                        if pair.priceUsd then
                            local price = tonumber(pair.priceUsd)
                            if price and price > 0 then
                                -- 对于BTC，价格应该在合理范围内
                                if token:upper() == "BTC" then
                                    if price > 10000 and price < 200000 then
                                        score = score + 50
                                    elseif price < 1 then
                                        score = score - 50 -- 惩罚过低价格
                                    end
                                end
                                -- 对于ETH，价格应该在合理范围内
                                if token:upper() == "ETH" then
                                    if price > 1000 and price < 10000 then
                                        score = score + 50
                                    elseif price < 100 then
                                        score = score - 50 -- 惩罚过低价格
                                    end
                                end
                            end
                        end
                        
                        -- 检查交易对年龄 (较新的交易对可能不太稳定)
                        if pair.pairCreatedAt then
                            local createdAt = tonumber(pair.pairCreatedAt)
                            if createdAt then
                                local age = os.time() - createdAt / 1000
                                if age > 86400 * 30 then -- 超过30天
                                    score = score + 5
                                end
                            end
                        end
                        
                        if score > bestScore then
                            bestScore = score
                            bestPair = pair
                        end
                    end
                    
                    if bestPair and bestPair.priceUsd then
                        results[token] = {
                            usd = tonumber(bestPair.priceUsd),
                            usd_24h_change = bestPair.priceChange and bestPair.priceChange.h24,
                            symbol = bestPair.baseToken and bestPair.baseToken.symbol or token,
                            chainId = bestPair.chainId,
                            dexId = bestPair.dexId,
                            pairAddress = bestPair.pairAddress,
                            liquidity = bestPair.liquidity and bestPair.liquidity.usd
                        }
                    end
                end
            end
            
            -- 所有请求完成后回调
            if completed == totalTokens then
                callback(true, results)
            end
        end)
    end
end

-- 更新菜单栏显示
local function updateMenuBar()
    if not menubar or not priceData then
        if menubar then
            local icon = config.showIcon and "🪙 " or ""
            menubar:setTitle(icon .. "加载中...")
        end
        return
    end
    
    local displayText = ""
    local icon = config.showIcon and "🪙 " or ""
    
    if config.displayFormat == "detailed" then
        -- 详细格式：显示所有币种
        local items = {}
        if config.apiProvider == "coingecko" then
            for i, coinId in ipairs(config.coingecko.coins) do
                if priceData[coinId] and priceData[coinId][config.coingecko.currency] then
                    local price = priceData[coinId][config.coingecko.currency]
                    local symbol = getCoinSymbol(coinId)
                    table.insert(items, symbol .. " $" .. formatPrice(price))
                end
            end
        elseif config.apiProvider == "dexscreener" then
            for i, token in ipairs(config.dexscreener.tokens) do
                if priceData[token] and priceData[token].usd then
                    local price = priceData[token].usd
                    local symbol = priceData[token].symbol or token
                    table.insert(items, symbol .. " $" .. formatPrice(price))
                end
            end
        end
        displayText = table.concat(items, " | ")
    else
        -- 紧凑格式：只显示第一个币种
        if config.apiProvider == "coingecko" then
            local firstCoin = config.coingecko.coins[1]
            if firstCoin and priceData[firstCoin] and priceData[firstCoin][config.coingecko.currency] then
                local price = priceData[firstCoin][config.coingecko.currency]
                local symbol = getCoinSymbol(firstCoin)
                displayText = symbol .. " $" .. formatPrice(price)
            end
        elseif config.apiProvider == "dexscreener" then
            local firstToken = config.dexscreener.tokens[1]
            if firstToken and priceData[firstToken] and priceData[firstToken].usd then
                local price = priceData[firstToken].usd
                local symbol = priceData[firstToken].symbol or firstToken
                displayText = symbol .. " $" .. formatPrice(price)
            end
        end
    end
    
    if displayText == "" then
        displayText = "获取失败"
    end
    
    menubar:setTitle(icon .. displayText)
end

-- 创建菜单项
local function createMenuItems()
    local menuItems = {}
    
    if priceData then
        -- 根据API提供商显示不同的数据
        if config.apiProvider == "coingecko" then
            for _, coinId in ipairs(config.coingecko.coins) do
                if priceData[coinId] and priceData[coinId][config.coingecko.currency] then
                    local coinInfo = priceData[coinId]
                    local price = coinInfo[config.coingecko.currency]
                    local change24h = coinInfo[config.coingecko.currency .. "_24h_change"]
                    local symbol = getCoinSymbol(coinId)
                    
                    local changeText = ""
                    if change24h then
                        local changeStr = string.format("%.2f%%", change24h)
                        if change24h > 0 then
                            changeText = " (📈 +" .. changeStr .. ")"
                        elseif change24h < 0 then
                            changeText = " (📉 " .. changeStr .. ")"
                        else
                            changeText = " (➡️ " .. changeStr .. ")"
                        end
                    end
                    
                    table.insert(menuItems, {
                        title = symbol .. ": $" .. formatPriceDetailed(price) .. changeText,
                        disabled = true
                    })
                end
            end
        elseif config.apiProvider == "dexscreener" then
            for _, token in ipairs(config.dexscreener.tokens) do
                if priceData[token] and priceData[token].usd then
                    local tokenInfo = priceData[token]
                    local price = tokenInfo.usd
                    local change24h = tokenInfo.usd_24h_change
                    local symbol = tokenInfo.symbol or token
                    
                    local changeText = ""
                    if change24h then
                        local changeStr = string.format("%.2f%%", change24h)
                        if change24h > 0 then
                            changeText = " (📈 +" .. changeStr .. ")"
                        elseif change24h < 0 then
                            changeText = " (📉 " .. changeStr .. ")"
                        else
                            changeText = " (➡️ " .. changeStr .. ")"
                        end
                    end
                    
                    local chainInfo = tokenInfo.chainId and " [" .. tokenInfo.chainId:upper() .. "]" or ""
                    
                    table.insert(menuItems, {
                        title = symbol .. ": $" .. formatPriceDetailed(price) .. changeText .. chainInfo,
                        disabled = true
                    })
                end
            end
        end
        
        table.insert(menuItems, {title = "-"})
        
        -- 刷新按钮
        table.insert(menuItems, {
            title = "🔄 刷新数据",
            fn = function()
                obj.updatePrices()
            end
        })
    else
        table.insert(menuItems, {
            title = "⏳ 加载中...",
            disabled = true
        })
        table.insert(menuItems, {
            title = "🔄 重试",
            fn = function()
                obj.updatePrices()
            end
        })
    end
    
    table.insert(menuItems, {title = "-"})
    
    -- 显示当前API提供商
    table.insert(menuItems, {
        title = "📊 数据源: " .. (config.apiProvider == "coingecko" and "CoinGecko" or "DexScreener"),
        disabled = true
    })
    
    table.insert(menuItems, {title = "-"})
    
    -- 配置选项
    table.insert(menuItems, {
        title = "⚙️ 重新加载配置",
        fn = function()
            obj.reloadConfig()
        end
    })
    
    -- 切换显示格式
    local formatText = config.displayFormat == "compact" and "详细显示" or "紧凑显示"
    table.insert(menuItems, {
        title = "🔀 " .. formatText,
        fn = function()
            config.displayFormat = config.displayFormat == "compact" and "detailed" or "compact"
            updateMenuBar()
            hs.alert.show("显示格式已切换为: " .. (config.displayFormat == "compact" and "紧凑" or "详细"))
        end
    })
    
    table.insert(menuItems, {title = "-"})
    
    -- 关于信息
    table.insert(menuItems, {
        title = "ℹ️ 关于",
        fn = function()
            local dataSource = config.apiProvider == "coingecko" and "CoinGecko" or "DexScreener"
            hs.alert.show("Crypto Price Monitor v" .. obj.version .. "\n数据来源: " .. dataSource .. " API")
        end
    })
    
    menubar:setMenu(menuItems)
end

-- 更新价格数据
function obj.updatePrices()
    if not config then return end
    
    if config.apiProvider == "coingecko" then
        fetchCoinGeckoPrice(config.coingecko.coins, config.coingecko.currency, function(success, data)
            if success then
                priceData = data
                updateMenuBar()
                createMenuItems()
            else
                hs.alert.show("获取价格失败: " .. tostring(data))
                priceData = nil
                updateMenuBar()
                createMenuItems()
            end
        end)
    elseif config.apiProvider == "dexscreener" then
        fetchDexScreenerPrice(config.dexscreener.tokens, config.dexscreener.preferredChains, function(success, data)
            if success then
                priceData = data
                updateMenuBar()
                createMenuItems()
            else
                hs.alert.show("获取价格失败: " .. tostring(data))
                priceData = nil
                updateMenuBar()
                createMenuItems()
            end
        end)
    end
end

-- 启动定时器
local function startTimer()
    if timer then
        timer:stop()
    end
    
    timer = hs.timer.doEvery(config.refreshInterval, function()
        obj.updatePrices()
    end)
end

-- 重新加载配置
function obj.reloadConfig()
    config = loadConfig()
    obj.updatePrices()
    startTimer()
    hs.alert.show("配置已重新加载")
end

-- 初始化模块
function obj.init()
    config = loadConfig()
    
    -- 创建菜单栏项
    menubar = hs.menubar.new()
    if not menubar then
        hs.alert.show("无法创建菜单栏项")
        return false
    end
    
    -- 初始化显示
    local icon = config.showIcon and "🪙 " or ""
    menubar:setTitle(icon .. "加载中...")
    
    -- 获取初始价格数据
    obj.updatePrices()
    
    -- 启动定时刷新
    startTimer()
    
    hs.alert.show("加密货币价格监控已启动")
    return true
end

-- 停止模块
function obj.stop()
    if timer then
        timer:stop()
        timer = nil
    end
    
    if menubar then
        menubar:delete()
        menubar = nil
    end
    
    priceData = nil
    hs.alert.show("加密货币价格监控已停止")
end

-- 开始模块
function obj.start()
    return obj.init()
end

-- 自动启动模块
obj.init()

return obj
