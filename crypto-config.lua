-- -----------------------------------------------------------------------
--                ** Crypto Price Monitor Configuration **              --
-- -----------------------------------------------------------------------

return {
    -- API 提供商 (coingecko 或 dexscreener)
    apiProvider = "dexscreener",
    
    -- CoinGecko 配置
    coingecko = {
        -- 要监控的加密货币列表 (CoinGecko ID)
        coins = {
            "ethereum",     -- ETH
            "bitcoin",      -- BTC
            "binancecoin",  -- BNB
            -- "cardano",      -- ADA
            -- "solana",       -- SOL
            -- "polkadot",     -- DOT
            -- "chainlink",    -- LINK
            -- "litecoin",     -- LTC
            -- "usd-coin",     -- USDC
            -- "ripple",       -- XRP
        },
        -- 显示货币 (usd, eur, jpy, cny 等)
        currency = "usd",
        -- API 密钥 (免费版无需密钥)
        apiKey = "",
    },
    
    -- DexScreener 配置
    dexscreener = {
        -- 要监控的代币列表 (搜索关键词或合约地址)
        tokens = {
            "ETH",     -- 使用 WETH 获取准确的 ETH 价格
            "BTC",     -- 使用 WBTC 获取准确的 BTC 价格
	          "SOL",
            "ctxhhwbovttrf1kc4zwfz8zf8bnw78n2uur3ozx5vfkb", -- 合约地址示例
            "gtj2s27ul7yz3tdtwpkjfncxeezrkrphjpj5fubwb8mk",
            "0x14c594222106283dd6d155b9d00a943b94153066",
        },
        -- 优先链 (可选，用于过滤结果)
        preferredChains = {"usdt", "solana"},
    },

    -- 刷新间隔 (秒)
    refreshInterval = 5,
    
    -- 是否显示图标
    showIcon = true,
    
    -- 显示格式
    -- "compact": 仅显示第一个币种，其他通过菜单查看
    -- "detailed": 在菜单栏显示所有币种
    displayFormat = "compact"
}

--[[
DexScreener 使用说明:

1. 对于主流币种建议使用包装版本:
   - BTC → WBTC (Wrapped Bitcoin)
   - ETH → WETH (Wrapped Ethereum)
   - 这样可以获得更准确的价格

2. 也可以直接使用合约地址:
   - "0x2260fac5e5542a773aa44fbcfedf7c193bc2c599"  -- WBTC
   - "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2"  -- WETH

3. 搜索策略:
   - 优先选择完全匹配的代币符号
   - 考虑流动性和交易量
   - 过滤掉价格明显异常的交易对
   - 优先选择在指定链上的交易对

4. 支持的链:
   - ethereum (以太坊)
   - bsc (币安智能链)
   - polygon (Polygon)
   - avalanche (雪崩)
   - arbitrum (Arbitrum)
   - optimism (Optimism)
   - 等等...

注意：DexScreener 主要用于 DEX 交易数据，价格可能与 CEX 有轻微差异
--]]
